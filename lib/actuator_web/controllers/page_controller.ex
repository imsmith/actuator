defmodule ActuatorWeb.PageController do
  @moduledoc "The scaffold landing page."
  use ActuatorWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
