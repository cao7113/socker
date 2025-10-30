defmodule Socker.EchoHandler do
  @moduledoc """
  A sample Handler implementation of the Echo protocol

  https://en.wikipedia.org/wiki/Echo_Protocol


  """

  use ThousandIsland.Handler

  require Logger

  # # simplify send call
  # import Kernel, except: [send: 2]
  # import ThousandIsland.Socket, only: [send: 2]
  alias ThousandIsland.Socket

  def send_msg(conn, msg), do: send(conn, msg)

  def get_socket(conn), do: GenServer.call(conn, :get_socket)

  def raw_socket(conn) do
    %ThousandIsland.Socket{socket: socket} = get_socket(conn)
    socket
  end

  def close_socket(conn) do
    socket = get_socket(conn)
    ThousandIsland.Socket.close(socket)
  end

  ## ThousandIsland.Handler callbacks

  @impl ThousandIsland.Handler
  def handle_connection(socket, state) do
    # Socket.sockname(socket) |> dbg
    {:ok, {_ip, _port} = peer} = Socket.peername(socket)

    # todo: use Registry!
    # conn_name = :"conn-#{port}"
    conn_num = Counter.next(:app_conn_counter)
    conn_name = :"conn#{conn_num}"

    Logger.info("handle_connection [#{conn_name}] from peer: #{peer |> inspect}")
    # send :conn0, "hi" # to send peer handled by handle_info system msg!
    Process.register(self(), conn_name)

    Socket.send(
      socket,
      "#{DateTime.utc_now()}: Connected #{conn_name} with state: #{state |> inspect} pid: #{self() |> inspect}\n"
    )

    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    data = "reply: " <> data
    Socket.send(socket, data)
    {:continue, state}
  end

  @impl ThousandIsland.Handler
  # called when the underlying socket is closed by the remote end
  def handle_close(_socket, state) do
    Logger.info("Connection closed #{DateTime.utc_now()}")
    {:cleanup_after_closed, state}
  end

  @impl ThousandIsland.Handler
  def handle_error(reason, _socket, state) do
    Logger.error("Error occurred: #{inspect(reason)}")

    # The underlying socket has already been closed by the time this callback is called. The return value is ignored.
    {:cleanup_after_error, state}
  end

  @impl ThousandIsland.Handler
  def handle_shutdown(socket, state) do
    # called when the server process itself is being shut down.
    # The underlying socket has NOT been closed by the time this callback is called. The return value is ignored.
    Logger.info("Server is shutting down, closing connection #{DateTime.utc_now()}")
    Socket.send(socket, "Server is shutting down, closing connection\n")
    {:cleanup_after_shutdown, state}
  end

  @impl ThousandIsland.Handler
  def handle_timeout(socket, state) do
    Logger.info("Connection timed out #{DateTime.utc_now()}")
    Socket.send(socket, "#{DateTime.utc_now()}: Connection timed out \n")

    # The underlying socket has NOT been closed by the time this callback is called. The return value is ignored.
    {:cleanup_after_timeout, state}
  end

  ## GenServer callbacks

  @impl GenServer
  def handle_call(:get_socket, _from, {socket, state}) do
    {:reply, socket, {socket, state}, socket.read_timeout}
  end

  def handle_call(msg, _from, {socket, state}) do
    # Do whatever you'd like with msg & from
    Socket.send(socket, "call with msg: #{msg}\n")
    {:reply, msg, {socket, state}, socket.read_timeout}
  end

  @impl GenServer
  def handle_cast(msg, {socket, state}) do
    # Do whatever you'd like with msg
    Logger.info("cast with msg: #{msg}")
    {:noreply, {socket, state}, socket.read_timeout}
  end

  # @impl GenServer
  # def handle_info(msg, {socket, state}) do
  #   # Do whatever you'd like with msg
  #   Logger.info("handle_info with msg: #{msg |> inspect}")
  #   Socket.send(socket, "msg: #{msg |> inspect} from handle_info callback\n")
  #   {:noreply, {socket, state}, socket.read_timeout}
  # end
end
