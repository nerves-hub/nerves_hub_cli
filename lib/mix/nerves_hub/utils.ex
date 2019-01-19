defmodule Mix.NervesHubCLI.Utils do
  alias NervesHubCLI.Config
  alias Mix.NervesHubCLI.Shell

  def product(opts) do
    Keyword.get(opts, :product) || config()[:name] || config()[:app]
  end

  @doc """
  Print the API endpoint that's being used to communicate with the NervesHub server
  """
  @spec show_api_endpoint() :: String.t()
  def show_api_endpoint() do
    endpoint = NervesHubCore.API.endpoint()
    uri = URI.parse(endpoint)

    Shell.info("NervesHub server: #{uri.host}:#{uri.port}")
  end

  def org(opts) do
    # command line options
    # environment
    # project
    # user
    # not found
    org =
      Keyword.get(opts, :org) || System.get_env("NERVES_HUB_ORG") ||
        Application.get_env(:nerves_hub, :org) || Config.get(:org) ||
        Shell.raise("""
        Cound not determine organization
        Organization is set in the following order

          From the command line
          
            --org org_name

          By setting the environment variable NERVES_HUB_ORG

            export NERVES_HUB_ORG=org_name

          By setting it in the project's config.exs

            config :nerves_hub,
              org: "org_name"

          Your user org from the NervesHub config

            NervesHubCLI.Config.get(:org)
        """)

    Shell.info("NervesHub org: #{org}")
    org
  end

  def firmware do
    images_path =
      (config()[:images_path] || Path.join([Mix.Project.build_path(), "nerves", "images"]))
      |> Path.expand()

    filename = "#{config()[:app]}.fw"
    Path.join(images_path, filename)
  end

  def metadata(firmware) do
    case System.cmd("fwup", ["-m", "-i", firmware]) do
      {metadata, 0} ->
        metadata =
          metadata
          |> String.trim()
          |> String.split("\n")
          |> Enum.map(&String.split(&1, "=", parts: 2))
          |> Enum.map(fn [k, v] -> {String.trim(k, "meta-"), String.trim(v, "\"")} end)
          |> Enum.into(%{})

        {:ok, metadata}

      {reason, _} ->
        {:error, reason}
    end
  end

  @spec fetch_metadata_item(String.t(), String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def fetch_metadata_item(metadata, key) when is_binary(key) do
    {:ok, regex} = "#{key}=\"(?<item>[^\n]+)\"" |> Regex.compile()

    case Regex.named_captures(regex, metadata) do
      %{"item" => item} -> {:ok, item}
      _ -> {:error, :not_found}
    end
  end

  @spec get_metadata_item(String.t(), String.t(), any()) :: String.t() | nil
  def get_metadata_item(metadata, key, default \\ nil) when is_binary(key) do
    case fetch_metadata_item(metadata, key) do
      {:ok, metadata_item} -> metadata_item
      {:error, :not_found} -> default
    end
  end

  def stringify(map) when is_map(map) do
    for {key, val} <- map, do: {to_string(key), val}, into: %{}
  end

  defp config() do
    Mix.Project.config()
  end
end
