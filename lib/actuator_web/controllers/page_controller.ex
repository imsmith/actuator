defmodule ActuatorWeb.PageController do
  use ActuatorWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
