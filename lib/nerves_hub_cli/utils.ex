defmodule NervesHubCLI.Utils do
  alias NervesHubCLI.Config
  alias NervesHubCLI.Shell

  @spec product(keyword()) :: String.t()
  def product(opts) do
    Keyword.get(opts, :product) || config()[:name] || config()[:app]
  end

  @doc """
  Print the API endpoint that's being used to communicate with the NervesHub server
  """
  @spec show_api_endpoint() :: :ok
  def show_api_endpoint() do
    endpoint = NervesHubUserAPI.API.endpoint()
    uri = URI.parse(endpoint)

    Shell.info("NervesHub server: #{uri.host}:#{uri.port}")
  end

  @spec org(keyword()) :: String.t()
  def org(opts) do
    # command-line options
    # environment
    # project
    # user
    # not found
    org =
      Keyword.get(opts, :org) || System.get_env("NERVES_HUB_ORG") ||
        org_from_env() || Config.get(:org) ||
        Shell.raise("""
        Cound not determine organization
        Organization is set in the following order

          From the command line

            --org org_name

          By setting the environment variable NERVES_HUB_ORG

            export NERVES_HUB_ORG=org_name

          By setting it in the project's config.exs

            config :nerves_hub_cli,
              org: "org_name"

          Your user org from the NervesHub config

            NervesHubCLI.Config.get(:org)
        """)

    Shell.info("NervesHub organization: #{org}")
    org
  end

  @doc """
  Return the path to the generated firmware bundle
  """
  @spec firmware() :: Path.t()
  def firmware do
    images_path =
      (config()[:images_path] || Path.join([Mix.Project.build_path(), "nerves", "images"]))
      |> Path.expand()

    filename = "#{config()[:app]}.fw"
    Path.join(images_path, filename)
  end

  @doc """
  Read the firmware metadata from the specified firmware bundle
  """
  @spec metadata(Path.t()) :: {:error, any()} | {:ok, map()}
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

  @doc """
  Turn map keys into strings
  """
  @spec stringify(map()) :: map()
  def stringify(map) when is_map(map) do
    for {key, val} <- map, do: {to_string(key), val}, into: %{}
  end

  @doc """
  Split up a string of comma-separated tags

  Invalid tags raise.

    iex> Mix.NervesHubCLI.Utils.split_tag_string("a, b, c")
    ["a", "b", "c"]

    iex> Mix.NervesHubCLI.Utils.split_tag_string("a space tag, b, c")
    ** (RuntimeError) Tag 'a space tag' should not contain white space

    iex> Mix.NervesHubCLI.Utils.split_tag_string("\\"tag_in_quotes\\"")
    ** (RuntimeError) Tag '\"tag_in_quotes\"' should not contain quotes

  """
  @spec split_tag_string(String.t()) :: [String.t()]
  def split_tag_string(str) do
    tags =
      str
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)

    Enum.each(tags, &check_valid_tag/1)

    tags
  end

  defp check_valid_tag(tag) do
    cond do
      String.contains?(tag, [" ", "\t", "\n"]) ->
        raise "Tag '#{tag}' should not contain white space"

      String.contains?(tag, ["\"", "'"]) ->
        raise "Tag '#{tag}' should not contain quotes"

      true ->
        :ok
    end
  end

  defp config() do
    # Mix.Project.config()
    []
  end

  defp org_from_env() do
    if Application.get_env(:nerves_hub, :org) do
      org = Application.get_env(:nerves_hub, :org)

      Shell.raise("""

      Specifying your NervesHub organization using the :nerves_hub application
      environment is no longer supported.

      Please edit your config.exs and replace:

        config :nerves_hub, org: "#{org}"

      With:

        config :nerves_hub_cli, org: "#{org}"

      Another source of this issue is having an old version of `:nerves_hub_link`.
      If you are using `:nerves_hub_link`, make sure that you're using v0.8.0 or
      later.
      """)
    else
      Application.get_env(:nerves_hub_cli, :org)
    end
  end
end
