defmodule Counter do
  @moduledoc """
  Counter
  """
  use Agent

  def start_link(initial_value \\ 0, opts \\ []) do
    Agent.start_link(fn -> initial_value end, opts)
  end

  def start!(initial_value \\ 0, name \\ __MODULE__) do
    {:ok, pid} = start_link(initial_value, name: name)
    pid
  end

  def pid(name \\ __MODULE__), do: Process.whereis(name) || start!(0, name)

  def state(name \\ __MODULE__), do: Agent.get(pid(name), & &1)
  def next(name \\ __MODULE__), do: Agent.get_and_update(pid(name), &{&1, &1 + 1})

  def value(name \\ __MODULE__), do: state(name)
  def increment(name \\ __MODULE__), do: Agent.update(pid(name), &(&1 + 1))
end
