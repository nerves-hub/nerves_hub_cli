import Config

config :nerves_hub_cli,
  home_dir: Path.expand(".nerves-hub")

config :nerves_hub_user_api,
  scheme: "http",
  host: "localhost",
  port: 4000
