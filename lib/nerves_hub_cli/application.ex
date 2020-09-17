defmodule NervesHubCLI.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  # use Application

  # def start(_type, _args) do
  #   NervesHubCLI.User.init()
  #   # List all child processes to be supervised
  #   children = [
  #     # Starts a worker by calling: NervesHubCLI.Worker.start_link(arg)
  #     # {NervesHubCLI.Worker, arg},
  #   ]

  #   # See https://hexdocs.pm/elixir/Supervisor.html
  #   # for other strategies and supported options
  #   opts = [strategy: :one_for_one, name: NervesHubCLI.Supervisor]
  #   Supervisor.start_link(children, opts)
  # end

  use Bakeware.Script

  alias NervesHubCLI.{Directives, Shell}

  @directives %{
    "ca_certificate" => Directives.CaCertificate,
    "deployment" => Directives.Deployment,
    "device" => Directives.Device,
    "firmware" => Directives.Firmware,
    "key" => Directives.Key,
    "org" => Directives.Org,
    "product" => Directives.Product,
    "user" => Directives.User
  }

  @help """
  NervesHubCLI #{Mix.Project.config()[:version]}

  Available commands:
  #{for {cmd, _} <- @directives, do: "\n\t" <> cmd}

  To get available options for a command, run:

  \tnh CMD help
  """

  def main([directive | args]) do
    NervesHubCLI.User.init()

    case Map.get(@directives, directive) do
      nil ->
        Shell.info(@help)

      mod ->
        mod.run(args)
    end

    0
  end

  def main(wat) do
    Shell.error("Invalid arguments: #{inspect(wat)}\n")
    Shell.info(@help)
    1
  end
end
