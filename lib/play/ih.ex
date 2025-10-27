defmodule Ih do
  def pp(info) do
    info |> IO.inspect(limit: :infinity)
    nil
  end
end
