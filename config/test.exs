import Config

config :nerves_hub_cli,
  home_dir: Path.expand("test/.nerves-hub"),
  scheme: "http",
  host: "0.0.0.0",
  port: 4002
