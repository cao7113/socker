defmodule Tcp do
  @moduledoc """
  Try tcp in hard way by yourself!!!
  just used in iex session!

  ## Server side
  # auto loop-accept multiple connections
  iex> s = Tcp.listen!
    >> Tcp.send! s, "ok"

  # accept one connection
  iex> l = Tcp.listen_sock!
    Tcp.accept_then_loop_recv(l)

  # accept once into process mailbox in active mode(once), then in active: false mode by :gen_tcp.recv/2
    iex(1)> l = Tcp.listen_sock! active: :once
    # 09:47:44.943 [info] Listing port 1234 [new_created] with opts: [active: :once]
    #Port<0.9>
    iex(2)> {:ok, s} = :gen_tcp.accept(l)
    {:ok, #Port<0.10>}
    iex(3)> flush
    {:tcp, #Port<0.10>, ~c"hi active-set-once\n"}
    :ok
  ## Socket data https://www.erlang.org/doc/apps/kernel/gen_tcp.html#connect/4-socket-data

  ## Client side
  shell> nc localhost 1234
    >> hi

  iex> s = Tcp.connect!
    >> Tcp.send! s, "hi"
    >> flush()

  只有服务端 listen，客户端connect时就进行了TCP 三次握手并建立了连接；可从WireShark上验证！
  """

  require Logger

  @default_listen_port 1234
  @listen_opts [
    # fix {:error, :eaddrinuse}
    reuseport: true,
    mode: :binary,
    # this setting use :gen_tcp.recv/1 to get message
    # other than handle_info/2 message from process mailbox with default setting active: true
    active: false
  ]

  ## Client

  def connect!(opts \\ []) do
    port = Keyword.get(opts, :port, @default_listen_port)

    # iex(4)> String.to_charlist "localhost"
    # ~c"localhost"
    :gen_tcp.connect(:localhost, port, opts) |> elem(1)
  end

  def send!(socket, data, opts \\ [new_line: true]) do
    data = if opts[:new_line], do: data <> "\n", else: data
    :ok = :gen_tcp.send(socket, data)
  end

  def recv!(socket, len \\ 0) do
    {:ok, data} = :gen_tcp.recv(socket, len)
    data
  end

  ## Server

  @doc """
  Listen and accept connections
  """
  def listen!(opts \\ @listen_opts) do
    %{listener_pid: listener_pid, listen_socket: lsock, port: lport} = get_listener!(opts)

    Task.start_link(fn ->
      conn_sup = get_conn_sup(lport)
      conn_manager = get_conn_manager(lport)
      loop_accept(lsock, lport, conn_sup, conn_manager)
    end)

    listener_pid
  end

  @doc """
  Listen connect without accepting; but can listen again with listen!() thanks to registered_name
  """
  def listen_sock!(opts \\ @listen_opts) do
    %{listen_socket: lsock} = get_listener!(opts)
    lsock
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

    {listener_pid, kind} =
      if not is_nil(found_pid) do
        {found_pid, :already_existed}
      else
        {:ok, listener_pid} =
          Agent.start_link(fn ->
            {:ok, lsock} = :gen_tcp.listen(port, opts)
            {:ok, {_ip, port}} = :inet.sockname(lsock)

            %{
              port: port,
              listen_socket: lsock,
              options: opts,
              registered_name: reg_name
            }
          end)

        {listener_pid, :new_created}
      end

    %{port: port, options: opts} = state = Agent.get(listener_pid, & &1)

    if kind == :new_created do
      reg_name = listener_name(port)
      Process.register(listener_pid, reg_name)
    end

    Logger.info("Listing port #{port} [#{kind}] with opts: #{inspect(opts)}")
    Map.put(state, :listener_pid, listener_pid)
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
    conn_num = Counter.next(:tcp_conn_counter)

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

  def accept_then_loop_recv(lsock) do
    {:ok, sock} = :gen_tcp.accept(lsock)
    loop_recv(sock)
  end

  def loop_recv(sock) do
    :gen_tcp.recv(sock, 0)
    |> case do
      {:ok, pack} ->
        pack = String.trim_trailing(pack)
        send!(sock, "reply: [#{pack}]")
        loop_recv(sock)

      err ->
        :gen_tcp.close(sock)
        err
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
