defmodule Net do
  @moduledoc """
  Net related helper functions
  """

  require Logger

  # :einval https://www.erlang.org/doc/apps/kernel/inet.html#module-posix-error-codes
  def parse_error(err), do: :inet.format_error(err)

  # https://www.erlang.org/doc/apps/erts/inet_cfg.html
  def rc, do: :inet.get_rc()

  @doc """
  Get local hostname
  """
  def hostname, do: :inet.gethostname()

  @doc """
  Get opening ports
  """
  def ports(proto \\ :tcp) do
    :inet.i(proto, :show_ports)
  end

  # :inet.i()
  # :inet.i :tcp, [:port, :module]

  def socket_info(socket) do
    # :inet.info(socket)
    [
      info: :inet.info(socket),
      # stat: :inet.getstat(socket),
      peer: :inet.peername(socket),
      sock: :inet.sockname(socket),
      port: :inet.port(socket)
    ]
  end

  # https://www.erlang.org/doc/apps/kernel/gen_tcp#t:option_name/0
  def socket_opts(socket) do
    :inet.getopts(socket, [
      # ​binary模式​：数据无需转换，直接以二进制形式存储，内存占用更小（二进制比列表更紧凑），且处理大文件或高吞吐量数据时性能更优（避免转换开销）。
      # ​list模式​：需将二进制转换为列表，会额外消耗 CPU 和内存（列表的每个元素是独立整数，存储开销更大）。处理大块数据时可能导致性能瓶颈。
      :mode,
      :active,
      :packet,
      # :raw,
      :nodelay,
      :keepalive,
      :debug,
      :send_timeout,
      :send_timeout_close,
      :reuseaddr,
      :reuseport,
      :reuseport_lb,
      :priority
    ])
  end

  # :inet.parse_address ~c"127.0.0.1"
  # {192, 168, 42, 2} => "192.168.42.2"
  def addr_to_string(addr) when is_tuple(addr), do: :inet.ntoa(addr) |> to_string()

  def addr_with_port({addr, port}) when is_tuple(addr) and is_integer(port),
    do: "#{addr_to_string(addr)}:#{port}"

  ## :socket module
  # This module provides an API for network sockets.
  # Functions are provided to create, delete and manipulate the sockets as well as sending and receiving data on them.
  # The intent is that it shall be as "close as possible" to the OS level socket interface.
  # https://www.erlang.org/doc/apps/kernel/socket.html

  ## :socket https://www.erlang.org/doc/apps/kernel/socket.html
  # :socket.i()
  # :socket.info()
  # :socket.number_of()
  # :socket.which_sockets()

  # :socket.supports
  def protocols, do: :socket.supports(:protocols)
  def show_protocols, do: protocols() |> Enum.sort() |> IO.inspect(limit: :infinity)

  def filter_protocol(name) do
    protocols()
    |> Enum.filter(fn {k, _v} ->
      k
      |> to_string()
      |> String.downcase()
      |> String.contains?(to_string(name))
    end)
  end
end
