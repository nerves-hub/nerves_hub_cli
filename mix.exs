defmodule NervesHubCLI.MixProject do
  use Mix.Project

  @description "NervesHub CLI"
  @version "3.0.0-rc.1"

  def project do
    [
      app: :nerves_hub_cli,
      description: @description,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      releases: releases()
    ]
  end

  def releases do
    [
      nh: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            "macos-aarch64": [os: :darwin, cpu: :aarch64],
            "macos-x86_64": [os: :darwin, cpu: :x86_64],
            "linux-aarch64": [os: :linux, cpu: :aarch64],
            "linux-x86_64": [os: :linux, cpu: :x86_64],
            "windows-x86_64": [os: :windows, cpu: :x86_64]
          ],
          no_clean: false,
          debug: Mix.env() != :prod
        ]
      ]
    ]
  end

  def application do
    [
      mod: {NervesHubCLI.EntryPoint, []}
    ]
  end

  defp deps do
    [
      # Avoid broken pbcs 0.1.3 version
      {:burrito, "~> 1.0"},
      {:pbcs, "== 0.1.2 or ~> 0.1.4"},
      {:castore, "~> 0.1 or ~> 1.0", optional: true},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.23", only: [:docs], runtime: false},
      {:jason, "~> 1.0"},
      {:mint, "~> 1.5"},
      {:nimble_csv, "~> 0.7 or ~> 1.1"},
      {:table_rex, "~> 2.0.0 or ~> 3.0 or ~> 4.0"},
      {:tesla, "~> 1.2.1 or ~> 1.3"},
      {:x509, "~> 0.3"},
      {:slipstream, "~> 1.2"}
    ]
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs],
      plt_add_apps: [:public_key, :asn1, :crypto, :mix],
      ignore_warnings: "dialyzer.ignore-warnings"
    ]
  end
end
