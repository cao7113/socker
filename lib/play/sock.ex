defmodule Sock do
  @moduledoc """
  Module for implementing a simple client and server with TCP and UDP.

  https://www.erlang.org/doc/apps/kernel/socket_usage#example

  NOTE:
  - :socket is low-level interface based-on OS-level socket!!!
  - should consider use :gen_[tcp|udp] firstly!

  # server session
  > Sock.server(4004)

  # client session
  > Sock.client(4004, "hi")
  """

  @type socket_family :: :inet | :inet6

  ## Client Part

  @doc """
  Starts a client that connects to the server and sends a message.
  """
  def client(%{family: family} = server_sock_addr, msg) when is_list(msg) or is_binary(msg) do
    with {:ok, sock} <- :socket.open(family, :stream, :default),
         :ok <- maybe_bind(sock, family),
         :ok <- :socket.connect(sock, server_sock_addr) do
      client_exchange(sock, msg)
    end
  end

  def client(server_port, msg) when is_integer(server_port) and server_port > 0 do
    family = :inet
    addr = get_local_addr(family)
    sock_addr = %{family: family, addr: addr, port: server_port}
    client(sock_addr, msg)
  end

  def client(server_port, server_addr, msg)
      when is_integer(server_port) and server_port > 0 and is_tuple(server_addr) do
    family = which_family(server_addr)
    sock_addr = %{family: family, addr: server_addr, port: server_port}
    client(sock_addr, msg)
  end

  defp client_exchange(sock, msg) when is_list(msg) do
    client_exchange(sock, IO.iodata_to_binary(msg))
  end

  defp client_exchange(sock, msg) when is_binary(msg) do
    :ok = :socket.send(sock, msg, :infinity)
    :socket.recv(sock, byte_size(msg), :infinity)
  end

  ## Server Part

  @doc """
  Starts a server that listens for incoming connections.
  """
  def server() do
    # Make system choose port (and address)
    server(0)
  end

  def server(%{family: family, addr: addr, port: _} = sock_addr) do
    with {:ok, sock} <- :socket.open(family, :stream, :tcp),
         :ok <- :socket.bind(sock, sock_addr),
         :ok <- :socket.listen(sock) do
      {:ok, %{port: port}} = :socket.sockname(sock)
      acceptor = start_acceptor(sock)
      {:ok, {port, addr, acceptor}}
    end
  end

  def server(port) when is_integer(port) do
    family = :inet
    addr = get_local_addr(family)
    sock_addr = %{family: family, addr: addr, port: port}
    server(sock_addr)
  end

  def server(port, addr) when is_integer(port) and port >= 0 and is_tuple(addr) do
    family = which_family(addr)
    sock_addr = %{family: family, addr: addr, port: port}
    server(sock_addr)
  end

  ## Acceptor
  defp start_acceptor(lsock) do
    self_pid = self()

    {_pid, mref} =
      spawn_monitor(fn ->
        acceptor_init(self_pid, lsock)
      end)

    receive do
      {:DOWN, _mref, :process, _pid, info} ->
        raise "Failed to start acceptor: #{inspect(info)}"

      {pid, :started} ->
        :socket.setopt(lsock, :otp, :owner, pid)
        send(pid, {self(), :continue})
        Process.demonitor(mref)
        pid
    end
  end

  defp acceptor_init(parent, lsock) do
    send(parent, {self(), :started})

    receive do
      {_parent, :continue} ->
        :ok
    end

    acceptor_loop(lsock)
  end

  defp acceptor_loop(lsock) do
    case :socket.accept(lsock, :infinity) do
      {:ok, asock} ->
        start_handler(asock)
        acceptor_loop(lsock)

      {:error, reason} ->
        raise "Accept failed: #{inspect(reason)}"
    end
  end

  ## Handler

  defp start_handler(sock) do
    self_pid = self()

    {_pid, mref} =
      spawn_monitor(fn ->
        handler_init(self_pid, sock)
      end)

    receive do
      {:DOWN, _mref, :process, _pid, info} ->
        raise "Failed to start handler: #{inspect(info)}"

      {pid, :started} ->
        :socket.setopt(sock, :otp, :owner, pid)
        send(pid, {self(), :continue})
        Process.demonitor(mref)
        pid
    end
  end

  defp handler_init(parent, sock) do
    send(parent, {self(), :started})

    receive do
      {_parent, :continue} ->
        :ok
    end

    handler_loop(sock, :undefined)
  end

  defp handler_loop(sock, :undefined) do
    case :socket.recv(sock, 0, :nowait) do
      {:ok, data} ->
        echo(sock, data)
        handler_loop(sock, :undefined)

      {:select, select_info} ->
        handler_loop(sock, select_info)

      {:completion, completion_info} ->
        handler_loop(sock, completion_info)

      {:error, reason} ->
        raise "Receive failed: #{inspect(reason)}"
    end
  end

  defp handler_loop(_sock, {:select_info, :recv, _select_handle}) do
    receive do
      {:socket, sock, :select, _select_handle} ->
        case :socket.recv(sock, 0, :nowait) do
          {:ok, data} ->
            echo(sock, data)
            handler_loop(sock, :undefined)

          {:select, new_select_info} ->
            handler_loop(sock, new_select_info)

          {:error, reason} ->
            raise "Receive failed: #{inspect(reason)}"
        end
    end
  end

  defp handler_loop(_sock, {:completion_info, :recv, _completion_handle}) do
    receive do
      {:socket, sock, :completion, {_completion_handle, completion_status}} ->
        case completion_status do
          {:ok, data} ->
            echo(sock, data)
            handler_loop(sock, :undefined)

          {:error, reason} ->
            raise "Receive failed: #{inspect(reason)}"
        end
    end
  end

  defp echo(sock, data) when is_binary(data) do
    :ok = :socket.send(sock, data, :infinity)
    IO.puts("** ECHO **")
    # IO.puts(binary_to_list(data))
    IO.puts(data)
  end

  ## Utils

  defp maybe_bind(sock, family) do
    maybe_bind(sock, family, :os.type())
  end

  defp maybe_bind(sock, family, {:win32, _}) do
    addr = get_local_addr(family)
    sock_addr = %{family: family, addr: addr, port: 0}
    :socket.bind(sock, sock_addr)
  end

  defp maybe_bind(_sock, _family, _os) do
    :ok
  end

  def get_local_addr(family \\ :inet) do
    filter = fn %{addr: %{family: fam}, flags: flags} ->
      fam == family and not Enum.member?(flags, :loopback)
    end

    {:ok, [sock_addr | _]} = :net.getifaddrs(filter)
    %{addr: %{addr: addr}} = sock_addr
    addr
  end

  def get_family_addrs(family \\ :inet) do
    filter = fn %{addr: %{family: fam}, flags: _flags} ->
      fam == family
    end

    {:ok, addrs} = :net.getifaddrs(filter)
    addrs
  end

  defp which_family(addr) when is_tuple(addr) and tuple_size(addr) == 4 do
    :inet
  end

  defp which_family(addr) when is_tuple(addr) and tuple_size(addr) == 8 do
    :inet6
  end
end
