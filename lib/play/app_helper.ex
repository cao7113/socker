defmodule AppHelper do
  def loaded_apps(), do: Application.loaded_applications() |> Enum.sort()
  def apps(), do: Application.started_applications() |> Enum.sort()

  def app_env(app) do
    Application.get_all_env(app)
  end

  # todo dep tree
end
