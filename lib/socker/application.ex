defmodule Socker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # {:normal, args}
    # args is passed at mix.exs mod: {Socker.Application, []}

    kland_log_level = Application.get_env(:socker, :kland_log_level, nil)

    if kland_log_level do
      ThousandIsland.Logger.attach_logger(kland_log_level)
    end

    children = [
      # Starts a worker by calling: Socker.Worker.start_link(arg)
      # {Socker.Worker, arg}
      {ThousandIsland, Socker.kland_opts()}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Socker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
