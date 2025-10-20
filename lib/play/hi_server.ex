defmodule HiServer do
  use GenServer

  ## User API

  def ping(pid \\ __MODULE__) do
    GenServer.call(pid, :ping)
  end

  def start!(opts \\ []) do
    {:ok, pid} = GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    pid
  end

  ## Callbacks

  @impl true
  def init(init_arg) do
    {:ok, init_arg}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end
end
