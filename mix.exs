defmodule NervesHubCLI.MixProject do
  use Mix.Project

  @version "0.11.1"
  @source_url "https://github.com/nerves-hub/nerves_hub_cli"

  def project do
    [
      app: :nerves_hub_cli,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      dialyzer: dialyzer(),
      preferred_cli_env: %{
        docs: :docs,
        "hex.publish": :docs,
        "hex.build": :docs
      }
    ]
  end

  def application do
    [
      mod: {NervesHubCLI.Application, []}
    ]
  end

  defp description do
    "NervesHub Mix command-line interface "
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp deps do
    [
      # Avoid broken pbcs 0.1.3 version
      {:pbcs, "== 0.1.2 or ~> 0.1.4"},
      {:x509, "~> 0.3"},
      {:nerves_hub_user_api, "~> 0.8.0"},
      {:table_rex, "~> 2.0.0 or ~> 3.0"},
      {:nimble_csv, "~> 0.7 or ~> 1.1"},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false},
      {:dialyxir, "~> 1.1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer() do
    [
      flags: [:race_conditions, :unmatched_returns, :error_handling, :underspecs],
      plt_add_apps: [:public_key, :asn1, :crypto, :mix],
      ignore_warnings: "dialyzer.ignore-warnings"
    ]
  end

  defp docs do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
