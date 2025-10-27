defmodule Kland do
  @moduledoc """
  Shortcuts for thousand_island utilts
  """

  require Logger

  def server, do: Process.whereis(Socker.kland_server_name())
  def listener(sup \\ server()), do: ThousandIsland.Server.listener_pid(sup)

  def acceptor_pool(sup \\ server()),
    do: ThousandIsland.Server.acceptor_pool_supervisor_pid(sup)

  def pool(sup \\ server()), do: acceptor_pool(sup)

  def acceptor_supervisors(sup \\ acceptor_pool()),
    do: ThousandIsland.AcceptorPoolSupervisor.acceptor_supervisor_pids(sup)

  def conn_supervisors(sup \\ acceptor_pool()) do
    acceptor_supervisors(sup)
    |> Enum.reduce([], fn asup, acc ->
      conn_sup = ThousandIsland.AcceptorSupervisor.connection_sup_pid(asup)
      [conn_sup | acc]
    end)
  end

  def get_connections(sups \\ conn_supervisors()) do
    sups
    |> Enum.reduce([], fn sup, acc ->
      childs = DynamicSupervisor.which_children(sup)
      childs ++ acc
    end)
  end

  def connection_pids(conns \\ get_connections()) do
    conns |> Enum.map(fn {:undefined, pid, :worker, _} -> pid end)
  end

  @doc """
  Send message by
  > send <conn_pid>, "hi"
  > Reg.find_name K.rand_conn
  """
  def rand_conn(conn_pids \\ connection_pids()),
    do: if(length(conn_pids) == 0, do: nil, else: Enum.random(conn_pids))

  def info do
    %{
      server: server(),
      listener: listener(),
      acceptor_pool: acceptor_pool(),
      acceptor_supervisors: acceptor_supervisors(),
      conn_supervisors: conn_supervisors()
    }
  end

  ## logging

  def enable_logging(level \\ :trace) do
    ThousandIsland.Logger.attach_logger(level)
  end

  def disable_logging(level \\ :info) do
    ThousandIsland.Logger.detach_logger(level)
  end
end
