use Mix.Config

config :nerves_hub_cli,
  home_dir: Path.expand(".nerves-hub")

config :nerves_hub_user_api,
  host: "0.0.0.0",
  port: 4002
