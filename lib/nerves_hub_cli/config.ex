defmodule NervesHubCLI.Config do
  @config "nerves-hub.config"

  @default_uri "https://manage.nervescloud.com"

  def uri do
    System.get_env("NERVES_HUB_URI") || get(:uri) || @default_uri
  end

  @doc """
  Get User Access Token for use with the session
  """
  def token(opts \\ []) do
    Keyword.get(opts, :token) ||
      System.get_env("NERVES_CLOUD_TOKEN") ||
      System.get_env("NERVES_HUB_TOKEN") ||
      get(:token)
  end

  def product(opts \\ []) do
    Keyword.get(opts, :product) ||
      System.get_env("NERVES_CLOUD_PRODUCT") ||
      System.get_env("NERVES_HUB_PRODUCT") ||
      get(:product)
  end

  def org(opts \\ []) do
    Keyword.get(opts, :org) ||
      System.get_env("NERVES_CLOUD_ORG") ||
      System.get_env("NERVES_HUB_ORG") ||
      get(:org)
  end

  def delete(key) do
    read()
    |> Map.delete(key)
    |> write()
  end

  def put(key, value) do
    read()
    |> Map.put(key, value)
    |> write()
  end

  def get(key) do
    read()
    |> Map.get(key)
  end

  defp read do
    with {:ok, binary} <- File.read(file()),
         {:ok, term} <- PBCS.Utils.safe_binary_to_term(binary) do
      term
    else
      _ -> %{}
    end
  end

  defp write(config) do
    unless File.dir?(NervesHubCLI.data_dir()) do
      File.mkdir_p!(NervesHubCLI.data_dir())
    end

    File.write(file(), :erlang.term_to_binary(config))
  end

  defp file do
    Path.join(NervesHubCLI.data_dir(), @config)
  end
end
