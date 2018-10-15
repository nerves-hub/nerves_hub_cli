defmodule NervesHubCLI.API do
  alias NervesHubCLI.Certificate
  require Record

  Record.defrecord(
    :hackney_client,
    :client,
    Record.extract(:client, from_lib: "hackney/include/hackney.hrl")
  )

  @host "api.nerves-hub.org"
  @port 443

  @file_chunk 4096
  @progress_steps 50

  def start_pool() do
    pool = :nerves_hub_cli
    pool_opts = [timeout: 150_000, max_connections: 10]
    :ok = :hackney_pool.start_pool(pool, pool_opts)
  end

  def request(_verb, _path, _body_or_params, _auth \\ %{})

  def request(:get, path, params, auth) when is_map(params) do
    url = url(path) <> "?" <> URI.encode_query(params)

    :hackney.request(:get, url, headers(), "", opts(auth))
    |> resp()
  end

  def request(verb, path, params, auth) when is_map(params) do
    with {:ok, body} <- Jason.encode(params) do
      request(verb, path, body, auth)
    end
  end

  def request(verb, path, body, auth) do
    :hackney.request(verb, url(path), headers(), body, opts(auth))
    |> resp()
  end

  def file_request(verb, path, file, params, auth) do
    {:ok, ref} = :hackney.request(verb, url(path), [], :stream_multipart, opts(auth))

    # Send params
    Enum.each(params, fn {k, v} ->
      :hackney.send_multipart_body(ref, {:data, to_string(k), to_string(v)})
    end)

    # Send the file
    content_length = :filelib.file_size(file)
    disposition = {"form-data", [{"name", "firmware"}, {"filename", Path.basename(file)}]}

    :hackney_manager.get_state(ref, fn client ->
      boundary =
        client
        |> hackney_client()
        |> Keyword.get(:mp_boundary)

      {mp_file_header, _} =
        :hackney_multipart.mp_file_header({:file, file, disposition, []}, boundary)

      case :hackney_request.stream_body(mp_file_header, client) do
        {:ok, client} ->
          stream = File.stream!(file, [], @file_chunk)

          Enum.reduce(stream, 0, fn chunk, sent ->
            :hackney_request.stream_body(chunk, client)

            size = sent + byte_size(chunk)

            if progress?() do
              put_progress(size, content_length)
            end

            size
          end)

          :hackney_request.stream_body(<<"\r\n">>, client)

          :hackney_multipart.mp_eof(boundary)
          |> :hackney_request.stream_body(client)

          :hackney.start_response(ref)
          |> resp()

        error ->
          error
      end
    end)
  end

  defp resp({:ok, status_code, _headers, client_ref})
       when status_code >= 200 and status_code < 300 do
    case :hackney.body(client_ref) do
      {:ok, ""} ->
        {:ok, ""}

      {:ok, body} ->
        Jason.decode(body)

      error ->
        error
    end
  after
    :hackney.close(client_ref)
  end

  defp resp({:ok, _status_code, _headers, client_ref}) do
    case :hackney.body(client_ref) do
      {:ok, ""} ->
        {:error, ""}

      {:ok, body} ->
        resp =
          case Jason.decode(body) do
            {:ok, body} -> body
            body -> body
          end

        {:error, resp}

      error ->
        error
    end
  after
    :hackney.close(client_ref)
  end

  defp resp(resp) do
    {:error, resp}
  end

  defp url(path) do
    endpoint() <> path
  end

  defp endpoint do
    config = config()
    host = config[:host]
    port = config[:port]
    "https://#{host}:#{port}/"
  end

  defp headers do
    [{"Content-Type", "application/json"}]
  end

  defp opts(auth) do
    ssl_options =
      auth
      |> ssl_options()
      |> Keyword.put(:cacerts, NervesHubCLI.User.ca_certs())

    [
      pool: :nerves_hub_cli,
      ssl_options: ssl_options,
      recv_timeout: 60_000
    ]
  end

  @spec ssl_options(NervesHubCLI.User.auth_map() | %{}) :: Keyword.t()
  defp ssl_options(%{key: key, cert: cert}) do
    [
      key: {:ECPrivateKey, Certificate.key_to_der(key)},
      cert: Certificate.cert_to_der(cert),
      server_name_indication: to_charlist(@host)
    ]
  end

  defp ssl_options(_), do: []

  defp config do
    Application.get_env(:nerves_hub_cli, __MODULE__) ||
      [
        host: System.get_env("NERVES_HUB_HOST") || @host,
        port: System.get_env("NERVES_HUB_PORT") || @port
      ]
  end

  def put_progress(size, max) do
    fraction = size / max
    completed = trunc(fraction * @progress_steps)
    percent = trunc(fraction * 100)
    unfilled = @progress_steps - completed

    IO.write(
      :stderr,
      "\r|#{String.duplicate("=", completed)}#{String.duplicate(" ", unfilled)}| #{percent}% (#{
        bytes_to_mb(size)
      } / #{bytes_to_mb(max)}) MB"
    )
  end

  defp bytes_to_mb(bytes) do
    trunc(bytes / 1024 / 1024)
  end

  defp progress?() do
    System.get_env("NERVES_LOG_DISABLE_PROGRESS_BAR") == nil
  end
end
