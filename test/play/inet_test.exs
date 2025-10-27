defmodule InetTest do
  @moduledoc """
  Try inet

  - https://www.erlang.org/doc/apps/kernel/inet.html
  """

  use ExUnit.Case

  @tag manual: true
  test "parse address" do
    # inet:parse_address("192.168.42.2").
    # {ok,{192,168,42,2}}
    # inet:parse_address("::FFFF:192.168.42.2").
    # {ok,{0,0,0,0,0,65535,49320,10754}}
    assert :inet.parse_address(~c"192.168.42.2") == {:ok, {192, 168, 42, 2}}
    assert "192.168.42.2" == {192, 168, 42, 2} |> :inet.ntoa() |> to_string()
  end
end
