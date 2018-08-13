defmodule NervesHubCLI do
  def home_dir do
    Application.get_env(:nerves_hub_cli, :home_dir) || System.get_env("NERVES_HUB_HOME") ||
      Path.expand("~/.nerves_hub")
  end

  def public_keys(keys) when is_list(keys) do
    keys = Enum.map(keys, &to_string/1)

    NervesHubCLI.Key.local_keys()
    |> Enum.filter(fn %{name: name} -> name in keys end)
    |> Enum.map(&Map.get(&1, :key))
  end
end
