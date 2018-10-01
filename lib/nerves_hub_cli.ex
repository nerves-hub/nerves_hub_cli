defmodule NervesHubCLI do
  def home_dir do
    override_dir =
      Application.get_env(:nerves_hub_cli, :home_dir) || System.get_env("NERVES_HUB_HOME")

    if override_dir == nil or override_dir == "" do
      Path.expand("~/.nerves-hub")
    else
      override_dir
    end
  end

  def public_keys([]), do: []

  def public_keys(keys) when is_list(keys) do
    org = Mix.NervesHubCLI.Utils.org([])
    local_keys = NervesHubCLI.Key.local_keys(org)

    Enum.reduce(keys, [], fn {key_name_or_bin, acc} ->
      maybe_key = find_key(key_name_or_bin, local_keys)
      if maybe_key, do: [maybe_key | acc], else: acc
    end)
  end

  defp find_key(key, _local_keys) when is_binary(key) do
    key
  end

  defp find_key(key_name, local_keys) when is_atom(key_name) do
    Enum.find_value(local_keys, fn %{name: name, key: key} ->
      to_string(key_name) == name && [key]
    end)
  end
end
