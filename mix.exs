defmodule NervesHubCLI.MixProject do
  use Mix.Project

  def project do
    [
      app: :nerves_hub_cli,
      version: "0.5.1",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [main: "readme", extras: ["README.md"]],
      description: description(),
      package: package(),
      dialyzer: [
        plt_add_apps: [:public_key, :asn1, :crypto, :mix],
        ignore_warnings: "dialyzer.ignore-warnings"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {NervesHubCLI.Application, []}
    ]
  end

  defp description do
    "NervesHub Mix command-line interface "
  end

  defp package do
    [
      maintainers: ["Justin Schneck"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/nerves-hub/nerves_hub_cli"}
    ]
  end

  defp deps do
    [
      {:pbcs, "~> 0.1"},
      {:x509, "~> 0.3"},
      {:nerves_hub_core, "~> 0.2", github: "nerves-hub/nerves_hub_core"},
      {:ex_doc, "~> 0.19", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev, :test], runtime: false}
    ]
  end
end
