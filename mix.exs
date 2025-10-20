defmodule Socker.MixProject do
  use Mix.Project

  def project do
    [
      app: :socker,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger] ++ extra_apps(Mix.env())
    ]
  end

  def extra_apps(:dev) do
    [
      :runtime_tools,
      # for observer
      :wx,
      :observer
    ]
  end

  def extra_apps(_), do: []

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}

      # learning on livebook
      {:kino, "~> 0.16.0"},
      {:kino_vega_lite, "~> 0.1.11"}
    ] ++ env_deps(Mix.env())
  end

  def env_deps(:dev),
    do: [
      {:thousand_island, path: "_local/thousand_island"}
    ]

  def env_deps(_),
    do: [
      {:thousand_island, "~> 1.4"}
    ]
end
