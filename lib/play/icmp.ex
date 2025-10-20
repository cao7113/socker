defmodule Icmp do
  @moduledoc """
  Play ICMP like ping

  ICMP (Internet Control Message Protocol) utilities
  - https://en.wikipedia.org/wiki/Internet_Control_Message_Protocol

  Links:
  - https://github.com/ityonemo/icmp/tree/master
  - https://github.com/dwyl/ping


  In sudo mode
  {:ok, sock} = :socket.open(:inet, :raw, :icmp)
  :socket.sendto(sock, icmp_packet, {dest_ip, 0})  # 发送 ICMP 报文
  """
end
