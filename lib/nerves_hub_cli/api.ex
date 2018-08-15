defmodule NervesHubCLI.API do
  @host "api.nerves-hub.org"
  @config [
    host: @host,
    port: 443
  ]

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

  def file_request(verb, path, file, auth) do
    :hackney.request(verb, url(path), [], {:file, file}, opts(auth))
    |> resp()
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

  defp ssl_options(%{key: key, cert: cert}) do
    [
      key: {:ECPrivateKey, key},
      cert: cert,
      server_name_indication: to_charlist(@host)
    ]
  end

  defp ssl_options(_), do: []

  defp config do
    Application.get_env(:nerves_hub_cli, __MODULE__) || @config
  end
end
