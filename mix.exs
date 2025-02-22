defmodule NervesHubCLI.MixProject do
  use Mix.Project

  @version "2.1.0"
  @source_url "https://github.com/nerves-hub/nerves_hub_cli"

  def project do
    [
      app: :nerves_hub_cli,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      dialyzer: dialyzer(),
      escript: escript(),
      preferred_cli_env: %{
        docs: :docs,
        "hex.publish": :docs,
        "hex.build": :docs
      }
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
      {:castore, "~> 0.1 or ~> 1.0", optional: true},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.23", only: [:docs], runtime: false},
      {:jason, "~> 1.0"},
      {:mint, "~> 1.5"},
      {:nimble_csv, "~> 0.7 or ~> 1.1"},
      {:table_rex, "~> 2.0.0 or ~> 3.0 or ~> 4.0"},
      {:tesla, "~> 1.2.1 or ~> 1.3"},
      {:x509, "~> 0.3"}
    ]
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs],
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

  def escript do
    [
      main_module: NervesHubCLI.CLI,
      name: :nerves_hub
    ]
  end
end
