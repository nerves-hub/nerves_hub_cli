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

  def home_dir do
    override_dir =
      Application.get_env(:nerves_hub_cli, :home_dir) || System.get_env("NERVES_HUB_HOME")

    if override_dir == nil or override_dir == "" do
      Path.expand("~/.nerves-hub")
    else
      override_dir
    end
  end

  @doc """
  Convert a list of fwup public keys or references into a list of keys.
  """
  @spec resolve_fwup_public_keys([fwup_public_key_ref()]) :: [binary()]
  def resolve_fwup_public_keys([]), do: []

  def resolve_fwup_public_keys(keys) when is_list(keys) do
    org = Mix.NervesHubCLI.Utils.org([])
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
end
