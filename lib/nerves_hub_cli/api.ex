defmodule NervesHubCLI.API do
  @host "api.nerves-hub.org"
  @port 443

  @file_chunk 4096
  @progress_steps 50

  use Tesla
  adapter(Tesla.Adapter.Hackney)
  if Mix.env() != :prod, do: plug(Tesla.Middleware.Logger)
  plug(Tesla.Middleware.FollowRedirects, max_redirects: 5)
  plug(Tesla.Middleware.JSON)

  def request(:get, path, params) when is_map(params) do
    client()
    |> request(method: :get, url: path, query: Map.to_list(params), opts: [adapter: opts(%{})])
    |> resp()
  end

  def request(verb, path, params, auth \\ %{}) do
    client()
    |> request(method: verb, url: path, body: params, opts: [adapter: opts(auth)])
    |> resp()
  end

  def file_request(verb, path, file, params, auth) do
    content_length = :filelib.file_size(file)
    {:ok, pid} = Agent.start_link(fn -> 0 end)

    stream =
      file
      |> File.stream!([], @file_chunk)
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

    client()
    |> request(method: verb, url: path, body: mp, opts: [adapter: opts(auth)])
    |> resp()
  end

  defp resp({:ok, %{status: status_code, body: body}})
       when status_code >= 200 and status_code < 300,
       do: {:ok, body}

  defp resp({:ok, %{body: body}}), do: {:error, body}

  defp resp({:error, _reason} = err), do: err

  defp client() do
    middleware = [
      {Tesla.Middleware.BaseUrl, endpoint()}
    ]

    Tesla.build_client(middleware)
  end

  defp endpoint do
    config = config()
    host = config[:host]
    port = config[:port]
    "https://#{host}:#{port}/"
  end

  defp opts(auth) do
    ssl_options =
      auth
      |> ssl_options()
      |> Keyword.put(:cacerts, NervesHubCLI.User.ca_certs())

    [
      ssl_options: ssl_options,
      recv_timeout: 60_000
    ]
  end

  @spec ssl_options(NervesHubCLI.User.auth_map() | %{}) :: Keyword.t()
  defp ssl_options(%{key: key, cert: cert}) do
    [
      key: {:ECPrivateKey, X509.PrivateKey.to_der(key)},
      cert: X509.Certificate.to_der(cert),
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
