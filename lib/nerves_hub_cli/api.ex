defmodule NervesHubCLI.API do
  @moduledoc false
  require Logger

  @file_chunk 4096
  @progress_steps 50

  @type role :: :admin | :delete | :write | :read

  @adapter Tesla.Adapter.Mint

  @doc """
  Return the URL that's used for connecting to NervesHub
  """
  @spec endpoint() :: String.t()
  def endpoint() do
    if server = System.get_env("NERVES_HUB_URI") || NervesHubCLI.Config.get(:uri) do
      URI.parse(server)
      |> URI.append_path("/api")
      |> URI.to_string()
    else
      scheme = System.get_env("NERVES_HUB_SCHEME")
      host = System.get_env("NERVES_HUB_HOST")
      port = get_env_as_integer("NERVES_HUB_PORT")

      %URI{scheme: scheme, host: host, port: port, path: "/api"} |> URI.to_string()
    end
  end

  def request(:get, path, params) when is_map(params) do
    client()
    |> Tesla.request(
      method: :get,
      url: URI.encode(path),
      query: Map.to_list(params),
      opts: [adapter: opts()]
    )
    |> resp()
  end

  def request(verb, path, params, auth \\ %{}) do
    client(auth)
    |> Tesla.request(
      method: verb,
      url: URI.encode(path),
      body: params,
      opts: [adapter: opts()]
    )
    |> resp()
  end

  @doc """
  Make a streaming HTTP request. Returns {:ok, pid} where pid will send chunks to the caller.

  The caller will receive messages in the form:
    {:chunk, data} - A chunk of response data
    {:done, status} - The response is complete
    {:error, reason} - An error occurred
  """
  def stream_request(verb, path, params, auth) do
    caller = self()
    url = URI.parse(endpoint() <> "/" <> URI.encode(path))

    pid =
      spawn_link(fn ->
        do_stream_request(caller, verb, url, params, auth)
      end)

    {:ok, pid}
  end

  defp do_stream_request(caller, verb, url, params, auth) do
    scheme = if url.scheme == "https", do: :https, else: :http
    port = url.port || if scheme == :https, do: 443, else: 80

    connect_opts =
      if scheme == :https do
        [
          transport_opts: [
            verify: :verify_peer,
            cacerts: ca_certs(),
            server_name_indication: to_charlist(url.host),
            customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
          ]
        ]
      else
        []
      end

    case Mint.HTTP.connect(scheme, url.host, port, connect_opts) do
      {:ok, conn} ->
        body = Jason.encode!(params)
        req_headers = stream_headers(auth, byte_size(body))
        path_with_query = url.path || "/"

        case Mint.HTTP.request(conn, String.upcase(to_string(verb)), path_with_query, req_headers, body) do
          {:ok, conn, request_ref} ->
            stream_response_loop(caller, conn, request_ref)

          {:error, _conn, reason} ->
            send(caller, {:error, reason})
        end

      {:error, reason} ->
        send(caller, {:error, reason})
    end
  end

  defp stream_headers(%{token: "nh" <> _ = token}, content_length) do
    [
      {"authorization", "token #{token}"},
      {"content-type", "application/json"},
      {"accept", "text/plain"},
      {"content-length", to_string(content_length)}
    ]
  end

  defp stream_headers(_, content_length) do
    [
      {"content-type", "application/json"},
      {"accept", "text/plain"},
      {"content-length", to_string(content_length)}
    ]
  end

  defp stream_response_loop(caller, conn, request_ref) do
    receive do
      message ->
        case Mint.HTTP.stream(conn, message) do
          :unknown ->
            stream_response_loop(caller, conn, request_ref)

          {:ok, conn, responses} ->
            case process_stream_responses(caller, responses, request_ref) do
              :continue ->
                stream_response_loop(caller, conn, request_ref)

              :done ->
                Mint.HTTP.close(conn)
            end

          {:error, _conn, reason, _responses} ->
            send(caller, {:error, reason})
        end
    after
      120_000 ->
        send(caller, {:error, :timeout})
    end
  end

  defp process_stream_responses(caller, responses, request_ref) do
    Enum.reduce_while(responses, :continue, fn
      {:status, ^request_ref, status}, _acc ->
        if status >= 200 and status < 300 do
          {:cont, :continue}
        else
          send(caller, {:error, {:http_status, status}})
          {:halt, :done}
        end

      {:headers, ^request_ref, _headers}, acc ->
        {:cont, acc}

      {:data, ^request_ref, data}, acc ->
        if byte_size(data) > 0 do
          send(caller, {:chunk, data})
        end

        {:cont, acc}

      {:done, ^request_ref}, _acc ->
        send(caller, :done)
        {:halt, :done}

      {:error, ^request_ref, reason}, _acc ->
        send(caller, {:error, reason})
        {:halt, :done}

      _other, acc ->
        {:cont, acc}
    end)
  end

  def file_request(verb, path, file, params, auth) do
    content_length = :filelib.file_size(file)
    {:ok, pid} = Agent.start_link(fn -> 0 end)

    stream =
      file
      |> File.stream!(@file_chunk, [])
      |> Stream.each(fn chunk ->
        Agent.update(pid, fn sent ->
          size = sent + byte_size(chunk)
          if progress?(), do: put_progress(size, content_length)
          size
        end)
      end)

    mp =
      Tesla.Multipart.new()
      |> Tesla.Multipart.add_file_content(stream, Path.basename(file), name: "firmware")
      |> (fn mp ->
            Enum.reduce(params, mp, fn {k, v}, mp ->
              Tesla.Multipart.add_field(mp, to_string(k), to_string(v))
            end)
          end).()

    client(auth)
    |> Tesla.request(
      method: verb,
      url: URI.encode(path),
      body: mp,
      opts: [adapter: opts()]
    )
    |> resp()
  end

  defp resp({:ok, %{status: status_code, body: body}})
       when status_code >= 200 and status_code < 300,
       do: {:ok, body}

  defp resp({:ok, %{body: body}}), do: {:error, body}

  defp resp({:error, _reason} = err), do: err

  defp client(auth \\ %{}) do
    Tesla.client(middleware(auth), @adapter)
  end

  defp middleware(auth) do
    [
      {Tesla.Middleware.BaseUrl, endpoint()},
      {Tesla.Middleware.Headers, headers(auth)},
      {Tesla.Middleware.FollowRedirects, max_redirects: 5},
      Tesla.Middleware.JSON,
      if(System.get_env("VERBOSE") == "true", do: Tesla.Middleware.Logger, else: nil)
    ]
    |> Enum.filter(& &1)
  end

  defp headers(%{token: "nh" <> _ = token}) do
    [{"Authorization", "token #{token}"}]
  end

  defp headers(_), do: []

  defp opts() do
    ssl_options =
      [
        verify: :verify_peer,
        server_name_indication: server_name_indication(),
        cacerts: ca_certs(),
        customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
      ]

    [
      ssl_options: ssl_options,
      recv_timeout: 60_000,
      protocols: [:http1],
      timeout: 300_000
    ]
  end

  defp server_name_indication do
    server = System.get_env("NERVES_HUB_URI") || NervesHubCLI.Config.get(:uri)

    URI.parse(server).host
    |> to_charlist()
  end

  def put_progress(size, max) do
    fraction = size / max
    completed = trunc(fraction * @progress_steps)
    percent = trunc(fraction * 100)
    unfilled = @progress_steps - completed

    IO.write(
      :stderr,
      "\r|#{String.duplicate("=", completed)}#{String.duplicate(" ", unfilled)}| #{percent}% (#{bytes_to_mb(size)} / #{bytes_to_mb(max)}) MB"
    )
  end

  defp bytes_to_mb(bytes) do
    trunc(bytes / 1024 / 1024)
  end

  defp progress?() do
    System.get_env("NERVES_LOG_DISABLE_PROGRESS_BAR") == nil
  end

  defp ca_certs do
    :public_key.cacerts_get()
  end

  defp get_env_as_integer(str) do
    case System.get_env(str) do
      nil -> nil
      value -> String.to_integer(value)
    end
  end
end
