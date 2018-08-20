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

  def public_keys(keys) when is_list(keys) do
    keys = Enum.map(keys, &to_string/1)
    org = Mix.NervesHubCLI.Utils.org([])

    NervesHubCLI.Key.local_keys(org)
    |> Enum.filter(fn %{name: name} -> name in keys end)
    |> Enum.map(&Map.get(&1, :key))
  end
end
