defmodule NervesHubCLI.CLI.Config do
  alias NervesHubCLI.CLI.Shell

  @switches []
  @valid_config_keys ["uri"]

  def run(args) do
    {opts, args} = OptionParser.parse!(args, strict: @switches)

    case args do
      ["set", key, value] when key in @valid_config_keys ->
        String.to_existing_atom(key)
        |> NervesHubCLI.Config.put(value)

      ["get", key] when key in @valid_config_keys ->
        value =
          String.to_existing_atom(key)
          |> NervesHubCLI.Config.get()

        Shell.info("#{key}: #{value}")
    end
  end
end
