defmodule NervesHubCLI.CLI.Utils do
  alias NervesHubCLI.Config
  alias NervesHubCLI.CLI.Shell

  @spec product(keyword()) :: String.t()
  def product(opts) do
    # Currently, in order of priority:
    # - check if the product was passed into the command
    # - read the environment variables for product
    # - global config, which was set via `nerves_hub config set product "my_product_name"`
    # - raise with error message
    #
    # TODO: the default product name was changed to the directory that `nerves_hub product create` was called from.
    # Should we make current directory name a default option as well?
    product =
      Keyword.get(opts, :product) || System.get_env("NERVES_HUB_PRODUCT") || Config.get(:product) ||
        Shell.raise("""
          Cound not determine product
          Product is set in the following order

            From the command line

              --product product_name

            By setting the environment variable NERVES_HUB_PRODUCT

              export NERVES_HUB_PRODUCT=product_name

            Via global configuration (this applies to all projects)

              nh config set product "product_name"
        """)

    Shell.info("NervesHub product: #{product}")
    product
  end

  @doc """
  Print the API endpoint that's being used to communicate with the NervesHub server
  """
  @spec show_api_endpoint() :: :ok
  def show_api_endpoint() do
    endpoint = NervesHubCLI.API.endpoint()
    uri = URI.parse(endpoint)

    if is_nil(uri.host) do
      Shell.raise("NervesHub URI was not set")
    end

    port = if(uri.port == 443, do: "", else: ":#{uri.port}")
    Shell.info([:cyan, "NervesHub Host: ", :reset, "#{uri.host}#{port}"])
  end

  @spec org(keyword()) :: String.t()
  def org(opts) do
    # Currently, in order of priority:
    # - check if the org was passed into the command
    # - read the environment variables for org
    # - global config, which was set via `nerves_hub config set org "my_product_name"`
    # - raise with error message
    org =
      Keyword.get(opts, :org) || System.get_env("NERVES_HUB_ORG") || Config.get(:org) ||
        Shell.raise("""
        Cound not determine organization

        Organization is set in the following order

          From the command line

            --org org_name

          By setting the environment variable NERVES_HUB_ORG

            export NERVES_HUB_ORG=org_name

          Via global configuration (this applies to all projects)

            nh config set org "org_name"
        """)

    Shell.info([:cyan, "Organization:   ", :reset, "#{org}"])
    org
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

  @doc """
  Takes the integer serial representation of a certificate serial number
  and converts it to a hex string with `:` separators to match typical
  output from OpenSSL
  """
  @spec serial_as_hex(binary | integer) :: binary
  def serial_as_hex(serial_int) when is_integer(serial_int) do
    serial_int
    |> Integer.to_string(16)
    |> to_charlist()
    |> Enum.chunk_every(2)
    |> Enum.join(":")
  end

  def serial_as_hex(serial_str) when is_binary(serial_str) do
    String.to_integer(serial_str)
    |> serial_as_hex()
  end

  @doc """
  Get User Access Token for use with the session
  """
  def token(opts \\ []) do
    opts[:token] ||
      System.get_env("NERVES_HUB_TOKEN") || System.get_env("NH_TOKEN") ||
      Config.get(:token)
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
end
