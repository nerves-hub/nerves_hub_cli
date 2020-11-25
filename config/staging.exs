use Mix.Config

config :nerves_hub_cli,
  home_dir: Path.expand(".nerves-hub")

config :nerves_hub_user_api,
  host: "api.staging.nerves-hub.org",
  port: 443,
  ca_certs: System.fetch_env!("NERVES_HUB_SSL_STAGING") |> Path.expand()
