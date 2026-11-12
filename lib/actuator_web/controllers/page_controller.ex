defmodule ActuatorWeb.PageController do
  @moduledoc "`/` sends the admin to the transducer list. The scaffold home template is unused."
  use ActuatorWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/admin/transducers")
  end
end
