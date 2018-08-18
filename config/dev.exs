use Mix.Config

config :nerves_hub_cli,
  home_dir: Path.expand(".nerves-hub"),
  ca_certs: Path.expand("test/fixtures")

config :nerves_hub_cli, NervesHubCLI.API,
  host: "0.0.0.0",
  port: 4002
