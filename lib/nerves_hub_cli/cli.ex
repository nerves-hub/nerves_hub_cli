defmodule NervesHubCLI.CLI do
  alias NervesHubCLI.CLI.Shell

  @valid_commands ~w"cacert deployment device firmware key org product user config help"

  def main([command | args]) when command in @valid_commands do
    case command do
      "cacert" -> NervesHubCLI.CLI.CACert.run(args)
      "deployment" -> NervesHubCLI.CLI.Deployment.run(args)
      "device" -> NervesHubCLI.CLI.Device.run(args)
      "firmware" -> NervesHubCLI.CLI.Firmware.run(args)
      "key" -> NervesHubCLI.CLI.Key.run(args)
      "org" -> NervesHubCLI.CLI.Org.run(args)
      "product" -> NervesHubCLI.CLI.Product.run(args)
      "user" -> NervesHubCLI.CLI.User.run(args)
      "config" -> NervesHubCLI.CLI.Config.run(args)
      "help" -> main([])
    end
  end

  def main(args) do
    Shell.header("NervesHub CLI")

    description_or_error(args)

    """
    ## Usage:

        #{executable()} <command> <subcommand> [flags]

    ## Commands:

    - `user`           - Sign in or out of NervesHub
    - `config`         - Global configuration for the CLI
    - `cacert`         - Organization CA Certificates
    - `deployment`     - Product deployments
    - `device`         - Manage devices
    - `firmware`       - Device firmware (publish, list, delete)
    - `key`            - Firmware signing keys
    - `org`            - Organization management
    - `product`        - Product management
    - `help`           - Prints this message

    To get more information about a specific command, run:

        #{executable()} help <command>

    Examples:

        $ #{executable()} user auth
        $ #{executable()} device list
        $ #{executable()} key create --name dev_key
    """
    |> Shell.markdown()
  end

  defp description_or_error(args) do
    if Enum.empty?(args) do
      Shell.info("""
      Welcome to the NervesHub CLI, the best way to manage your organizations,
      products, and devices via the command line.
      """)
    else
      Shell.error("Command not recognized: #{executable()} #{Enum.join(args, " ")}\n")
    end
  end

  def executable, do: "nhcli"
end
