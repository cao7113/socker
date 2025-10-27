defmodule Socker.MixProject do
  # https://hexdocs.pm/mix/Mix.Project.html
  use Mix.Project

  def config, do: Mix.Project.config() |> Enum.sort()

  def project do
    # IO.puts("## project() called")
    [
      app: :socker,
      version: "0.1.0",
      description: "socket playground",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # https://hexdocs.pm/mix/Mix.Tasks.Compile.App.html
  # Mix.Project.compile_path() # _build/dev/lib/socker/ebin
  # Run "mix help compile.app" to learn about applications.
  def application do
    # https://www.erlang.org/doc/apps/kernel/app.html#file-syntax
    [
      # Application.get_env(:socker, :key1)
      # overridable by config/config.exs
      env: [key1: :test_value1],
      # registered: [Socker.Supervisor],
      # :extra_applications - a list of OTP applications your application depends on which are not included in :deps.
      # Mix guarantees all non-optional applications are started before your application starts.
      extra_applications:
        [:logger, :ssl, :public_key, ex_unit: :optional] ++ extra_apps(Mix.env()),
      # included_applications: [],
      # :mod - specifies a module to invoke when the application is started. It must be in the format {Mod, args} where args is often an empty list. The module specified must implement the callbacks defined by the Application module.
      mod: {Socker.Application, [1, :test_app_arg2]}
    ]
  end

  def extra_apps(:dev) do
    [
      :runtime_tools,
      # :observer app to inspect
      :wx,
      :observer
    ]
  end

  def extra_apps(_), do: []

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:machete, ">= 0.0.0", only: [:dev, :test]}
    ] ++
      env_deps(Mix.env())
  end

  def env_deps(:dev),
    do: [
      # Livebook tools
      {:kino, "~> 0.16.0"},
      {:kino_vega_lite, "~> 0.1.11"},
      # local path to debug
      {:thousand_island, path: "thousand_island"}
    ]

  def env_deps(_),
    do: [
      {:thousand_island, "~> 1.4"}
    ]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
