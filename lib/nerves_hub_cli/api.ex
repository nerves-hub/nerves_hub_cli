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
      |> append_path("/api")
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

  defmodule VendoredURI do
    @doc """
      This function is copied straight out of `URI.append_path/1`'s implementation.
      It can be removed once the minimum version of the library is raised to 1.5 or above
    """
    @spec append_path(URI.t(), String.t()) :: URI.t()
    def append_path(%URI{}, "//" <> _ = path) do
      raise ArgumentError, ~s|path cannot start with "//", got: #{inspect(path)}|
    end

    def append_path(%URI{path: path} = uri, "/" <> rest = all) do
      cond do
        path == nil -> %{uri | path: all}
        path != "" and :binary.last(path) == ?/ -> %{uri | path: path <> rest}
        true -> %{uri | path: path <> all}
      end
    end

    def append_path(%URI{}, path) when is_binary(path) do
      raise ArgumentError, ~s|path must start with "/", got: #{inspect(path)}|
    end
  end

  defp append_path(%URI{} = uri, path) do
    [maj, min] =
      System.version()
      |> String.split(".")
      |> Enum.take(2)
      |> Enum.map(&String.to_integer/1)

    if maj >= 1 && min >= 15 do
      URI.append_path(uri, path)
    else
      VendoredURI.append_path(uri, path)
    end
  end
end
