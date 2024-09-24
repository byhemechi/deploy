defmodule BzDeploy.MixProject do
  use Mix.Project

  def project do
    [
      app: :bz_deploy,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:yaml_elixir, "~> 2.9"},
      {:jason, "~> 1.2"},
      {:k8s, "~> 1.1"}
    ]
  end
end
