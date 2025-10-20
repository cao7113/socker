# defmodule SocksHello do
#   use GenServer
#   require Logger

#   def start_link(port) do
#     GenServer.start_link(__MODULE__, port, name: __MODULE__)
#   end

#   def port, do: System.get_env("PORT", "1088") |> String.to_integer()

#   def connect(
#         host \\ ~c"localhost",
#         port \\ port(),
#         opts \\ [:binary, packet: :raw, active: false]
#       ) do
#     {:ok, socket} = :gen_tcp.connect(host, port, opts)
#     socket
#   end

#   def init(port) do
#     {:ok, listen_socket} =
#       :gen_tcp.listen(port, [:binary, packet: :raw, active: false, reuseaddr: true])

#     Logger.info("SOCKS server listening on port #{port}")

#     # Start accepting connections in a separate process
#     Task.start(fn ->
#       loop_accept(listen_socket)
#     end)

#     {:ok, %{listen_socket: listen_socket}}
#   end

#   defp loop_accept(listen_socket) do
#     case :gen_tcp.accept(listen_socket) do
#       {:ok, socket} ->
#         Logger.info("Client connected: #{socket |> inspect}")

#         Task.start(fn ->
#           handle_client(socket)
#         end)

#         loop_accept(listen_socket)

#       {:error, reason} ->
#         Logger.error("Failed to accept connection: #{reason}")
#     end
#   end

#   defp handle_client(socket) do
#     # handshake
#     with {:ok, <<5, nmethods::integer-size(8), _methods::bytes-size(nmethods)>> = pkt} <-
#            :gen_tcp.recv(socket, 0),
#          Logger.info("recv packet nmethods: #{pkt |> inspect}"),
#          :ok <- :gen_tcp.send(socket, <<5, 0>>),
#          Logger.info("Socks reply selected method: 0, no auth required"),
#          {:ok, request} <- :gen_tcp.recv(socket, 0) do
#       Logger.info("recv request: #{request |> inspect}")

#       case parse_request(request) do
#         {:ok, address, port} ->
#           Logger.info("connecting target: #{{address, port} |> inspect()}")
#           connect_to_target(socket, {address, port})

#         {:error, reason} ->
#           Logger.error("Failed to parse request: #{{reason, request} |> inspect}")
#           :gen_tcp.close(socket)
#       end
#     else
#       reason ->
#         Logger.error("Failed to handle client request reason: #{reason |> inspect}")
#         :gen_tcp.close(socket)
#     end
#   end

#   defp connect_to_target(client_socket, {address, port}) do
#     case resolve_address(address) do
#       {:ok, ip} ->
#         case :gen_tcp.connect(ip, port, [:binary, packet: :raw, active: false]) do
#           {:ok, target_socket} ->
#             # :gen_tcp.send(client_socket, <<5, 0, 0, 1, 0, 0, 0, 0, port::big-16>>)
#             :gen_tcp.send(client_socket, <<5, 0, 0, 1, 0, 0, 0, 0, 0::big-16>>)
#             relay(client_socket, target_socket)

#           {:error, _reason} ->
#             Logger.error("Failed to connect to target #{address}:#{port}")
#             :gen_tcp.close(client_socket)
#         end

#       {:error, _reason} ->
#         Logger.error("Failed to resolve address #{address}")
#         :gen_tcp.close(client_socket)
#     end
#   end

#   defp relay(client_socket, target_socket) do
#     # 有问题，不能支持redirect， https等场景！
#     forward_data(client_socket, target_socket)
#     forward_data(target_socket, client_socket)
#   end

#   defp forward_data(from_socket, to_socket) do
#     Logger.info(
#       "[#{System.unique_integer([:positive])}}] start forward_data from #{from_socket |> inspect} to #{to_socket |> inspect} "
#     )

#     case :gen_tcp.recv(from_socket, 0) do
#       {:ok, data} ->
#         Logger.info(
#           "sending data from #{from_socket |> inspect} to #{to_socket |> inspect}: #{inspect(data, limit: :infinity, binaries: :as_strings)}"
#         )

#         :gen_tcp.send(to_socket, data)

#       {:error, reason} ->
#         Logger.error(
#           "forward_data from #{from_socket |> inspect} to #{to_socket |> inspect} failed reason: #{reason |> inspect}"
#         )

#         :gen_tcp.close(from_socket)
#         :gen_tcp.close(to_socket)
#         Logger.warning("#{{from_socket, to_socket} |> inspect} closed")
#     end
#   end

#   defp resolve_address(domain) when is_binary(domain) do
#     {:ok, String.to_charlist(domain)}
#     # domain = String.to_charlist(domain)

#     # case :inet.gethostbyname(domain) do
#     #   {:ok, [ip]} -> {:ok, ip}
#     #   {:ok, _} -> {:error, "Multiple IPs not supported"}
#     #   {:error, _} -> {:error, "Failed to resolve domain"}
#     # end
#   end

#   defp resolve_address({ip1, ip2, ip3, ip4}) do
#     {:ok, {ip1, ip2, ip3, ip4}}
#   end

#   defp parse_request(<<5, 1, 0, 1, rest::binary>>) do
#     # IPv4 address
#     <<ip1, ip2, ip3, ip4, port::big-16>> = rest
#     {:ok, {ip1, ip2, ip3, ip4}, port}
#   end

#   defp parse_request(<<5, 1, 0, 3, rest::binary>>) do
#     # Domain name address
#     <<domain_length::integer-size(8), domain::binary-size(domain_length), port::big-16>> = rest
#     # domain = String.slice(domain, 0, domain_length)
#     {:ok, domain, port}
#   end

#   defp parse_request(<<5, 1, 0, 4, _rest::binary>>) do
#     # IPv6 address (not supported)
#     {:error, "IPv6 address not supported"}
#   end

#   defp parse_request(<<5, 1, 0, other, _rest::binary>>) do
#     {:error, "Unsupported address type: #{other}"}
#   end
# end
