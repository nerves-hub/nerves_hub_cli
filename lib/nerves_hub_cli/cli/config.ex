defmodule NervesHubCLI.CLI.Config do
  alias NervesHubCLI.CLI.Shell

  @switches []
  @valid_config_keys ["uri", "product", "org"]

  def run(args) do
    {_opts, args} = OptionParser.parse!(args, strict: @switches)

    case args do
      ["set", key, value] when key in @valid_config_keys ->
        String.to_atom(key)
        |> NervesHubCLI.Config.put(value)

        Shell.info("Set config for #{key}")

      ["get", key] when key in @valid_config_keys ->
        value =
          String.to_atom(key)
          |> NervesHubCLI.Config.get()

        Shell.info("#{key}: #{value}")

      ["clear", key] when key in @valid_config_keys ->
        String.to_atom(key)
        |> NervesHubCLI.Config.delete()

        Shell.info("Cleared config for #{key}")

      _ ->
        render_help()
    end
  end

  @spec render_help() :: no_return()
  def render_help() do
    Shell.raise("""
    Invalid arguments to `nh config`.

    Usage:
      nh config set KEY VALUE
      nh device get KEY
      nh config clear KEY

    Valid keys are: #{Enum.join(@valid_config_keys, ", ")}

    Run `nh help config` for more information.
    """)
  end
end
