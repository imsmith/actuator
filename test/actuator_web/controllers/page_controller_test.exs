defmodule ActuatorWeb.PageControllerTest do
  use ActuatorWeb.ConnCase

  test "GET / sends the admin to the transducer list", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/admin/transducers"
  end
end
