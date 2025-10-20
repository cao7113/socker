defmodule Kland do
  @moduledoc """
  Play thounsand-island
  """

  @port 4000
  @server_name ThousandIsland.Server

  @default_opts [
    port: @port,
    # handler_module: HTTPHelloWorld,
    handler_module: Socker.Handler.Echo,
    handler_options: [],
    supervisor_options: [name: @server_name],
    # require: num_listen_sockets <= num_acceptors
    num_listen_sockets: 2,
    # default 100,
    num_acceptors: 4,
    # transport_options: [reuseport: true, debug: true],
    transport_options: [reuseport: true],
    # https://hexdocs.pm/elixir/1.18.4/GenServer.html#t:debug/0
    # [:trace | :log | :statistics | {:log_to_file, Path.t()}]
    # to underlying handler GenServer.start_link(__MODULE__, handler_options, genserver_options)
    genserver_options: [debug: [:log]]
  ]

  require Logger

  @doc """
  """
  def start!(opts \\ [log: :trace]) do
    opts = Keyword.merge(@default_opts, opts)

    {log, opts} = Keyword.pop(opts, :log)

    if log do
      enable_logging(log)
    end

    {:ok, sup_pid} = ThousandIsland.start_link(opts)

    Logger.info("Server started on port http://localhost:#{opts[:port]}")
    sup_pid
  end

  def restart!(opts \\ [], pid \\ get_server()) do
    ThousandIsland.stop(pid)
    start!(opts)
  end

  def listener_pid(pid \\ get_server()) do
    ThousandIsland.Server.listener_pid(pid)
  end

  def acceptor_pool_pid(pid \\ get_server()) do
    ThousandIsland.Server.acceptor_pool_supervisor_pid(pid)
  end

  def acceptor_pids(pid \\ acceptor_pool_pid()) do
    pid
    |> ThousandIsland.AcceptorPoolSupervisor.acceptor_supervisor_pids()
  end

  def get_server, do: Process.whereis(@server_name)

  ## logging

  def enable_logging(level \\ :trace) do
    ThousandIsland.Logger.attach_logger(level)
  end

  def disable_logging(level \\ :info) do
    ThousandIsland.Logger.detach_logger(level)
  end
end
