defmodule GenTcpTest do
  @moduledoc """
  Try :gen_tcp

  - https://www.erlang.org/doc/apps/kernel/gen_tcp.html
  """

  use ExUnit.Case

  @moduletag manual: true

  test "list mode: Received Packets are delivered as lists of bytes, [byte/0]" do
    # default mode is :list
    {:ok, listen_socket} = :gen_tcp.listen(0, mode: :list, active: false)
    {:ok, port} = :inet.port(listen_socket)
    parent = self()

    spawn_link(fn ->
      {:ok, socket} = :gen_tcp.accept(listen_socket)
      # use recv in passive mode
      {:ok, pkt} = :gen_tcp.recv(socket, 0)
      send(parent, {:reply, pkt})
    end)

    {:ok, csock} = :gen_tcp.connect(~c"localhost", port, [])
    :ok = :gen_tcp.send(csock, "hello")

    receive do
      msg ->
        assert {:reply, ~c"hello"} = msg
        assert is_list(~c"hello")
    end
  end

  test "binary mode: Received Packets are delivered as binary/0s" do
    # default mode is :list
    {:ok, listen_socket} = :gen_tcp.listen(0, mode: :binary, active: false)
    {:ok, port} = :inet.port(listen_socket)
    parent = self()

    spawn_link(fn ->
      {:ok, socket} = :gen_tcp.accept(listen_socket)
      {:ok, pkt} = :gen_tcp.recv(socket, 0)
      send(parent, {:reply, pkt})
    end)

    {:ok, csock} = :gen_tcp.connect(~c"localhost", port, [])
    :ok = :gen_tcp.send(csock, "hello")

    receive do
      msg ->
        assert {:reply, "hello"} = msg
        assert is_binary("hello")
    end
  end

  # 设置接收模式（active模式下数据会推送到 Erlang 进程信箱，false则需手动 recv）

  test "passive mode msg delivered" do
    {:ok, listen_socket} = :gen_tcp.listen(0, active: false)
    {:ok, port} = :inet.port(listen_socket)
    parent = self()

    spawn_link(fn ->
      {:ok, socket} = :gen_tcp.accept(listen_socket)
      # socket |> NetHelper.socket_opts() |> IO.inspect(label: "accept socket info")
      # use recv in passive mode
      {:ok, pkt} = :gen_tcp.recv(socket, 0)
      send(parent, {:reply, pkt})
    end)

    {:ok, csock} = :gen_tcp.connect(~c"localhost", port, active: false)
    # csock |> NetHelper.socket_opts() |> IO.inspect(label: "client socket info")
    :ok = :gen_tcp.send(csock, "hello")

    receive do
      msg -> assert {:reply, ~c"hello"} = msg
    end
  end

  test "active mode msg delivered" do
    # https://www.erlang.org/doc/apps/kernel/gen_tcp.html#connect/4-socket-data
    {:ok, listen_socket} =
      :gen_tcp.listen(0, [
        {:inet_backend, :socket},
        :binary,
        active: true,
        backlog: 33,
        debug: false
      ])

    {:ok, port} = :inet.port(listen_socket)

    parent = self()

    spawn_link(fn ->
      {:ok, socket} = :gen_tcp.accept(listen_socket)

      # get peer(client) info
      {:ok, {client_ip, _client_port}} = :inet.peername(socket)
      # # {{127, 0, 0, 1}, 64301}
      assert client_ip == {127, 0, 0, 1}

      # donot use :gen_tcp.recv/2 in active mode, but received as msg
      receive do
        msg ->
          send(parent, {:reply, msg})
      end
    end)

    {:ok, client_socket} =
      :gen_tcp.connect(~c"localhost", port, [{:inet_backend, :inet}, :binary, debug: false])

    :ok = :gen_tcp.send(client_socket, "hello")

    receive do
      msg -> assert {:reply, {:tcp, _, "hello"}} = msg
    end
  end

  test "server listen, accept, recv and client connect" do
    port = 12345
    opts = [:binary, packet: :raw, active: false]
    {:ok, listen_socket} = :gen_tcp.listen(port, opts)

    spawn_link(fn ->
      {:ok, socket} = :gen_tcp.accept(listen_socket)
      loop_acceptor(socket)
    end)

    {:ok, client_socket} =
      :gen_tcp.connect(~c"localhost", port, [:binary, packet: :raw, active: false])

    {:ok, {_, ^port}} = :inet.peername(client_socket)

    {:ok, client_port} = :inet.port(client_socket)
    {:ok, {_, ^client_port}} = :inet.sockname(client_socket)

    :ok = :gen_tcp.send(client_socket, "hello")
    {:ok, reply} = :gen_tcp.recv(client_socket, 0)
    assert "ok: hello" == reply
  end

  def loop_acceptor(socket) do
    :gen_tcp.recv(socket, 0)
    |> case do
      {:ok, packet} ->
        :gen_tcp.send(socket, "ok: " <> packet)
        loop_acceptor(socket)

      err ->
        err
    end
  end

  @tag :manual
  test "listen alreay listened socket" do
    port = 12345
    opts = [:binary, packet: :raw, active: false, reuseaddr: true]
    {:ok, listen_socket} = :gen_tcp.listen(port, opts)
    assert :gen_tcp.listen(port, opts) == {:error, :eaddrinuse}

    {:ok,
     [
       recv_oct: 0,
       recv_cnt: 0,
       recv_max: 0,
       recv_avg: 0,
       recv_dvi: 0,
       send_oct: 0,
       send_cnt: 0,
       send_max: 0,
       send_avg: 0,
       send_pend: 0
     ]} = :inet.getstat(listen_socket)

    assert :inet.peername(listen_socket) == {:error, :enotconn}
    :ok = :gen_tcp.close(listen_socket)
    assert {:error, :einval} == :inet.getstat(listen_socket)
  end
end
