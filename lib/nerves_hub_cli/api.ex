defmodule NervesHubCLI.API do
  @moduledoc false
  require Logger

  @file_chunk 4096
  @progress_steps 50

  @type role :: :admin | :delete | :write | :read

  use Tesla
  adapter(Tesla.Adapter.Hackney, pool: :nerves_hub_cli)
  if Mix.env() == :dev, do: plug(Tesla.Middleware.Logger)
  plug(Tesla.Middleware.FollowRedirects, max_redirects: 5)
  plug(Tesla.Middleware.JSON)

  @doc """
  Return the URL that's used for connecting to NervesHub
  """
  @spec endpoint() :: String.t()
  def endpoint() do
    opts = Application.get_all_env(:nerves_hub_cli)
    scheme = System.get_env("NERVES_HUB_SCHEME") || opts[:scheme]
    host = System.get_env("NERVES_HUB_HOST") || opts[:host]
    port = get_env_as_integer("NERVES_HUB_PORT") || opts[:port]

    %URI{scheme: scheme, host: host, port: port, path: "/api"} |> URI.to_string()
  end

  def request(:get, path, params) when is_map(params) do
    client()
    |> request(
      method: :get,
      url: URI.encode(path),
      query: Map.to_list(params),
      opts: [adapter: opts()]
    )
    |> resp()
  end

  def request(verb, path, params, auth \\ %{}) do
    client(auth)
    |> request(method: verb, url: URI.encode(path), body: params, opts: [adapter: opts()])
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

    client(auth)
    |> request(method: verb, url: URI.encode(path), body: mp, opts: [adapter: opts()])
    |> resp()
  end

  defp resp({:ok, %{status: status_code, body: body}})
       when status_code >= 200 and status_code < 300,
       do: {:ok, body}

  defp resp({:ok, %{body: body}}), do: {:error, body}

  defp resp({:error, _reason} = err), do: err

  defp client(auth \\ %{}) do
    middleware = [
      {Tesla.Middleware.BaseUrl, endpoint()},
      {Tesla.Middleware.Headers, headers(auth)}
    ]

    Tesla.client(middleware)
  end

  defp headers(%{token: "nh" <> _ = token}) do
    [{"Authorization", "token #{token}"}]
  end

  defp headers(_), do: []

  defp opts() do
    ssl_options = [
      verify: :verify_peer,
      server_name_indication: server_name_indication(),
      cacerts: ca_certs(),
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]

    [
      ssl_options: ssl_options,
      recv_timeout: 60_000
    ]
  end

  defp server_name_indication do
    Application.get_env(:nerves_hub_cli, :server_name_indication) ||
      Application.get_env(:nerves_hub_cli, :host) |> to_charlist()
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

  @doc "Returns a list of der encoded CA certs"
  @spec ca_certs() :: [binary()]
  def ca_certs do
    ssl = Application.get_env(:nerves_hub_cli, :ssl, [])
    ca_store = Application.get_env(:nerves_hub_cli, :ca_store)

    cond do
      # prefer explicit SSL setting if available
      is_list(ssl[:cacerts]) ->
        ssl[:cacerts]

      is_atom(ca_store) and !is_nil(ca_store) ->
        ca_store.ca_certs()

      true ->
        scheme = Application.get_env(:nerves_hub_cli, :scheme)
        host = Application.get_env(:nerves_hub_cli, :host)

        unless is_nil(ca_store) && scheme == "http" && host == "localhost" do
          Logger.warn(
            "[NervesHubLink] No CA store or :cacerts have been specified. Request will fail"
          )
        end

        []
    end
  end

  defp get_env_as_integer(str) do
    case System.get_env(str) do
      nil -> nil
      value -> String.to_integer(value)
    end
  end
end
