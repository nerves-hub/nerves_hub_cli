defmodule NervesHubCLI.CLI do
  alias NervesHubCLI.CLI.Shell

  @valid_commands ~w"ca_certificate deployment device firmware key org product user help config"

  def main([command | args]) when command in @valid_commands do
    case command do
      "ca_certificate" -> NervesHubCLI.CLI.CaCertificate.run(args)
      "deployment" -> NervesHubCLI.CLI.Deployment.run(args)
      "device" -> NervesHubCLI.CLI.Device.run(args)
      "firmware" -> NervesHubCLI.CLI.Firmware.run(args)
      "key" -> NervesHubCLI.CLI.Key.run(args)
      "org" -> NervesHubCLI.CLI.Org.run(args)
      "product" -> NervesHubCLI.CLI.Product.run(args)
      "user" -> NervesHubCLI.CLI.User.run(args)
      "config" -> NervesHubCLI.CLI.Config.run(args)
    end
  end

  def main(_args) do
    """
    This is nerves_hub CLI, the command line app to manage NervesHub resources.

    Usage:
      #{executable()} <command> <subcommand> [flags] 

    Commands:
      user:           Manage the signed in NervesHub user
      config:         Manage the global configuration for NervesHub CLI
      certificate:    Manage CA certificates for validating device connections
      deployment:     Manage deployments on NervesHub
      device:         Manage devices on NervesHub
      firmware:       Manage firmware on NervesHub
      key:            Manage firmware signing keys
      org:            Manage a NervesHub organization
      product:        Manage products on NervesHub
      help:           Prints this message

    To get more information about a specific command, run:
    #{executable()} help <command>

    Examples:
      $ #{executable()} user auth
      $ #{executable()} device list
      $ #{executable()} key create --name dev_key
    """
    |> Shell.info()
  end

  defp executable, do: "nerves_hub"
end
