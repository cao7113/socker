defmodule KlandTest do
  use ExUnit.Case, async: true

  use Machete

  defmodule Echo do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(socket, state) do
      {:ok, data} = ThousandIsland.Socket.recv(socket, 0)
      ThousandIsland.Socket.send(socket, data)
      {:close, state}
    end
  end

  defmodule Goodbye do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_shutdown(socket, state) do
      ThousandIsland.Socket.send(socket, "GOODBYE")
      {:close, state}
    end
  end

  defmodule ReadOpt do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_data(data, socket, state) do
      opts = [String.to_atom(data)]
      ThousandIsland.Socket.send(socket, inspect(ThousandIsland.Socket.getopts(socket, opts)))
      {:close, state}
    end
  end

  defmodule Whoami do
    use ThousandIsland.Handler

    @impl ThousandIsland.Handler
    def handle_connection(socket, state) do
      ThousandIsland.Socket.send(socket, :erlang.pid_to_list(self()))
      {:continue, state}
    end
  end

  describe "configuration" do
    test "ssl should allow default options to be overridden" do
      {:ok, _, port} =
        start_handler(ReadOpt,
          transport_module: ThousandIsland.Transports.SSL,
          transport_options: [
            send_timeout: 1230,
            certfile: Path.join(__DIR__, "support/cert.pem"),
            keyfile: Path.join(__DIR__, "support/key.pem")
          ]
        )

      {:ok, client} =
        :ssl.connect(:localhost, port,
          active: false,
          # verify: :verify_none,
          verify: :verify_peer,
          cacertfile: Path.join(__DIR__, "support/ca.pem")
        )

      :ssl.send(client, "send_timeout")
      {:ok, ~c"{:ok, [send_timeout: 1230]}"} = :ssl.recv(client, 0, 100)
    end
  end

  def start_handler(handler, opts \\ []) do
    resolved_args = opts |> Keyword.put_new(:port, 0) |> Keyword.put(:handler_module, handler)
    {:ok, server_pid} = start_supervised({ThousandIsland, resolved_args})
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server_pid)
    {:ok, server_pid, port}
  end
end
