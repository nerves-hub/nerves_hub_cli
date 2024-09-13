defmodule NervesHubCLI.CLI do
  alias NervesHubCLI.CLI.Shell

  @valid_commands ~w"certificate deployment device firmware key org product user help config"

  def main([command | args]) when command in @valid_commands do
    case command do
      "ca_certificate" -> Mix.Tasks.NervesHub.CaCertificate.run(args)
      "deployment" -> NervesHubCLI.CLI.Deployment.run(args)
      "device" -> Mix.Tasks.NervesHub.Device.run(args)
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
    This is nerves_hub_cli, the command line app to manage NervesHub resources.

    Usage:
      #{executable()} <command> <subcommand> [flags] 

    Commands:
      user:\t\t\tManage your NervesHub user account
      config:\t\tManage CLI configuration options which are persisted between calls
      certificate:\t\tManage CA certificates for validating device connections
      deployment:\t\tManage NervesHub deployments
      device:\t\tManage your NervesHub devices
      firmware:\t\tManage firmware on NervesHub
      key:\t\t\tManage firmware signing keys
      org:\t\t\tManages an organization
      product:\t\tManages your products on NervesHub
      help:\t\t\tPrints this message

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
