defmodule Socker do
  @moduledoc """
  Documentation for `Socker`.
  """

  @port 1234
  @server_name ThousandIsland.Server

  # todo merge from configration
  @default_opts [
    port: @port,
    supervisor_options: [name: @server_name],
    read_timeout: 300_000,
    handler_module: Socker.EchoHandler,
    handler_options: [],
    # require: num_listen_sockets <= num_acceptors
    num_listen_sockets: 1,
    # default 100,
    num_acceptors: 2,
    transport_module: ThousandIsland.Transports.TCP,
    # transport_options: [reuseport: true, debug: true],
    transport_options: [reuseport: true],
    # https://hexdocs.pm/elixir/1.18.4/GenServer.html#t:debug/0
    # [:trace | :log | :statistics | {:log_to_file, Path.t()}]
    # to underlying handler GenServer.start_link(__MODULE__, handler_options, genserver_options)
    genserver_options: [
      # debug: [:log]
    ]
  ]

  def app_sup, do: Process.whereis(Socker.Supervisor)
  def sup, do: app_sup()

  def default_port, do: @port

  def kland_opts() do
    env_opts = Application.get_env(:socker, :kland_opts, [])
    @default_opts |> Keyword.merge(env_opts)
  end

  def kland_server_name, do: @server_name
end
