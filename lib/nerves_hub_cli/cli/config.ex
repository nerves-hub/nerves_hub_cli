defmodule NervesHubCLI.CLI.Config do
  alias NervesHubCLI.CLI.Shell

  @switches []
  @valid_config_keys ["uri", "product", "org"]

  def run(args) do
    {_opts, args} = OptionParser.parse!(args, strict: @switches)

    case args do
      ["set", key, value] when key in @valid_config_keys ->
        # TODO: double check the usage of `String.to_atom/1` here. Should be safe since guarded
        String.to_atom(key)
        |> NervesHubCLI.Config.put(value)

      ["get", key] when key in @valid_config_keys ->
        value =
          String.to_atom(key)
          |> NervesHubCLI.Config.get()

        Shell.info("#{key}: #{value}")
    end
  end
end
