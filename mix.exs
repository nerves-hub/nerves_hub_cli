defmodule NervesHubCLI.MixProject do
  use Mix.Project

  def project do
    [
      app: :nerves_hub_cli,
      version: "0.3.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [main: "readme", extras: ["README.md"]],
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {NervesHubCLI.Application, []}
    ]
  end

  defp description do
    "NervesHub Mix command line interface "
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
      {:jason, "~> 1.0"},
      {:hackney, "~> 1.9"},
      {:pbcs, "~> 0.1"},
      {:x509, "~> 0.3"},
      {:ex_doc, "~> 0.19", only: [:dev, :test], runtime: false}
    ]
  end
end
