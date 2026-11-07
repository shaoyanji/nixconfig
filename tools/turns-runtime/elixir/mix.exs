defmodule TurnsBench.MixProject do
  use Mix.Project

  def project do
    [
      app: :turns_bench,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [turns_bench: [include_executables_for: [:unix]]]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {TurnsBench.Application, []}
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.16"},
      {:bandit, "~> 1.6"},
      {:jason, "~> 1.4"}
    ]
  end
end
