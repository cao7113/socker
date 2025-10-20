defmodule Tcp do
  @moduledoc """
  Try tcp in hard way by self!
  just used in iex session!

  ## Server side
  iex> s = Tcp.listen! port: 1234
    >> Tcp.send! s, "ok"

  ## Client side
  shell> nc localhost 1234
    >> hi

  iex> s = Tcp.connect! 1234
    >> Tcp.send! s, "hi"
    >> flush
  """

  require Logger

  @default_listen_port 1234
  @listen_opts [
    # fix {:error, :eaddrinuse}
    reuseport: true,
    mode: :binary,
    active: false
  ]

  ## Client

  def connect!(port, opts \\ []) do
    # iex(4)> String.to_charlist "localhost"
    # ~c"localhost"
    :gen_tcp.connect(:localhost, port, opts) |> elem(1)
  end

  def send!(socket, data, opts \\ [new_line: true]) do
    data = if opts[:new_line], do: data <> "\n", else: data
    :ok = :gen_tcp.send(socket, data)
  end

  ## Server

  def listen!(opts \\ @listen_opts) do
    {listener_pid, %{listen_socket: lsock, port: lport}} = get_listener!(opts)
    conn_sup = get_conn_sup(lport)
    conn_manager = get_conn_manager(lport)

    Task.start_link(fn ->
      loop_accept(lsock, lport, conn_sup, conn_manager)
    end)

    listener_pid
  end

  def reply(data, conn_num \\ 0, listen_port \\ @default_listen_port) when is_integer(conn_num) do
    sock = conn_socket(conn_num, listen_port)

    if sock do
      send!(sock, ">> " <> data)
    else
      raise "Not found socket for conn_num: #{conn_num}"
    end
  end

  @doc """
  Get playing registered listener based on Agent depend only on listening port!
  """
  def get_listener!(opts \\ @listen_opts) when is_list(opts) do
    {port, opts} = Keyword.pop(opts, :port, @default_listen_port)
    reg_name = listener_name(port)
    found_pid = Process.whereis(reg_name)

    {agent_pid, kind} =
      if not is_nil(found_pid) do
        {found_pid, :already_existed}
      else
        agent_opts = if port == 0, do: [], else: [name: reg_name]

        {:ok, agent_pid} =
          Agent.start_link(
            fn ->
              {:ok, lsock} = :gen_tcp.listen(port, opts)

              %{
                port: port,
                listen_socket: lsock,
                options: opts,
                registered_name: reg_name
              }
            end,
            agent_opts
          )

        # todo register dynamic name on port == 0

        {agent_pid, :new_created}
      end

    %{port: port, options: opts} = state = Agent.get(agent_pid, & &1)
    Logger.info("Listing port #{port} [#{kind}] with opts: #{inspect(opts)}")
    {agent_pid, state}
  end

  def listener_name(0), do: nil
  def listener_name(port) when is_integer(port), do: :"tcp_listener_#{port}"

  def get_conn_sup(listen_port \\ @default_listen_port) do
    name = :"tcp_conn_sup_#{listen_port}"
    pid = Process.whereis(name)

    if pid do
      pid
    else
      {:ok, pid} = Task.Supervisor.start_link(name: name)
      pid
    end
  end

  def connection_pids(listen_port \\ @default_listen_port) do
    sup = get_conn_sup(listen_port)
    Task.Supervisor.children(sup)
  end

  def get_conn_manager(listen_port \\ @default_listen_port) do
    name = :"tcp_conn_manager_#{listen_port}"
    pid = Process.whereis(name)

    if pid do
      pid
    else
      {:ok, pid} = Agent.start_link(fn -> %{} end, name: name)
      pid
    end
  end

  def get_connections(listen_port \\ @default_listen_port) do
    conn_manager = get_conn_manager(listen_port)
    Agent.get(conn_manager, & &1)
  end

  def conn_socket(conn_num \\ 0, listen_port \\ @default_listen_port)
      when is_integer(conn_num) do
    conn = get_connections(listen_port)[conn_num]

    if conn do
      %{socket: sock} = conn
      sock
    end
  end

  def loop_accept(lsock, lport, conn_sup, conn_manager) do
    {:ok, sock} = :gen_tcp.accept(lsock)
    {:ok, {_ip, _port} = peer} = :inet.peername(sock)
    peer_info = peer |> Net.addr_with_port()
    conn_num = Counter.next(:tcp_conn)

    {:ok, conn_pid} =
      Task.Supervisor.start_child(conn_sup, fn ->
        send!(sock, ">> Conn##{conn_num} connected with pid: #{self() |> inspect}, q to Quit!")
        do_recv(sock, conn_num, conn_manager, peer_info)
      end)

    Agent.update(conn_manager, fn s ->
      Map.put(s, conn_num, %{socket: sock, conn_pid: conn_pid, peer: peer})
    end)

    Logger.info(
      "Accepted connection##{conn_num} from #{peer_info} handling with #{conn_pid |> inspect}"
    )

    loop_accept(lsock, lport, conn_sup, conn_manager)
  end

  defp do_recv(sock, conn_num, conn_manager, info, cnt \\ 0) do
    :gen_tcp.recv(sock, 0)
    |> case do
      {:ok, pack} ->
        pack = String.trim_trailing(pack)

        if pack in ["q", "quit", "e", "exit"] do
          send!(sock, ">> Conn##{conn_num} [#{cnt}]: Server closed")
          :gen_tcp.close(sock)
        else
          msg =
            case pack do
              "hi" -> "Hello"
              "ping" -> "Pong"
              "time" -> "Server time: #{DateTime.utc_now()}"
              _ -> pack
            end

          send!(sock, ">> Conn##{conn_num} [#{cnt}]: #{msg} to #{info}")
          do_recv(sock, conn_num, conn_manager, info, cnt + 1)
        end

      {:error, :closed} ->
        Logger.info("!!! Conn##{conn_num} closed from client #{info}")
        cleanup_socket(sock, conn_manager, conn_num, info)
        :ok

      {:error, err} ->
        send!(sock, ">> Conn##{conn_num} error #{inspect(err)} from #{info}")
        cleanup_socket(sock, conn_manager, conn_num, info)
        :error
    end
  end

  defp cleanup_socket(sock, conn_manager, conn_num, info) do
    Agent.update(conn_manager, fn s ->
      Logger.info("!!! Conn##{conn_num} cleanup conn state for client #{info}")
      Map.delete(s, conn_num)
    end)

    :gen_tcp.close(sock)
  end
end
