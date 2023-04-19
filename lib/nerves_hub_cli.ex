defmodule NervesHubCLI do
  alias Mix.NervesHubCLI.Shell

  @moduledoc """
  TBD
  """

  @typedoc """
  Firmware update public keys can be referred to by an atom name or by their contents.
  """
  @type fwup_public_key_ref :: String.t() | atom()

  @spec default_description() :: String.t()
  def default_description() do
    {:ok, hostname} = :inet.gethostname()
    to_string(hostname)
  end

  def home_dir() do
    from_config = Application.get_env(:nerves_hub_cli, :home_dir)
    from_env = System.get_env("NERVES_HUB_HOME")
    xdg_home_nh = :filename.basedir(:user_data, "nerves-hub", %{os: :linux})

    cond do
      valid_home_dir(from_config) ->
        Path.expand(from_config)

      valid_home_dir(from_env) ->
        Path.expand(from_env)

      System.get_env("XDG_DATA_HOME") ->
        # User set XDG_DATA_HOME so let it pass through
        xdg_home_nh

      File.dir?(Path.expand("~/.nerves-hub")) and not File.dir?(xdg_home_nh) ->
        # By this point, defaults are going to be used.
        # If the old default exists, but the new XDG default does not, then fail to
        # give the user a chance for easier migration
        Shell.error("""
        NervesHubCLI has migrated to use the XDG Base Directory Specifiction and
        no longer uses the default base directory of ~/.nerves-hub.

        Unfortunately, this requires a one-time manual migration since you currently
        have configuration stored in ~/.nerves-hub. To continue, please run ¬

          $ mv ~/.nerves-hub #{xdg_home_nh}
        """)

        :erlang.halt(1)

      true ->
        # Use default $XDG_DATA_HOME/nerves-hub
        xdg_home_nh
    end
  end

  @doc """
  Convert a list of fwup public keys or references into a list of keys.
  """
  @spec resolve_fwup_public_keys([fwup_public_key_ref()], binary() | nil) :: [binary()]
  def resolve_fwup_public_keys(keys, org \\ nil)

  def resolve_fwup_public_keys([], _org), do: []

  def resolve_fwup_public_keys(keys, org) when is_list(keys) do
    opts = if is_bitstring(org), do: [org: org], else: []

    org = Mix.NervesHubCLI.Utils.org(opts)
    local_keys = NervesHubCLI.Key.local_keys(org)

    Enum.reduce(keys, [], &[find_key(&1, local_keys) | &2])
  end

  defp find_key(key, _local_keys) when is_binary(key), do: key

  defp find_key(key_name, local_keys) when is_atom(key_name) do
    value =
      Enum.find_value(local_keys, fn %{name: name, key: key} ->
        to_string(key_name) == name && key
      end)

    case value do
      nil -> Shell.raise("NervesHub is unable to find key: #{inspect(key_name)}")
      value -> value
    end
  end

  defp valid_home_dir(dir) do
    is_binary(dir) and dir != ""
  end
end
