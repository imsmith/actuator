defmodule ActuatorWeb.ListenerDocLiveTest do
  use ActuatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Actuator.TransducersFixtures
  alias Actuator.Transducers.Instances

  test "shows a curl example per enabled transducer", %{conn: conn} do
    t = transducer_fixture()
    on_exit(fn -> Instances.stop(t.name) end)
    conn = put_req_header(conn, "authorization", "Basic " <> Base.encode64("admin:dev-token"))
    {:ok, view, _} = live(conn, ~p"/admin/listener")
    assert has_element?(view, "#openapi-link")
    assert has_element?(view, "#doc-#{t.name} pre", "curl -X POST")
    assert has_element?(view, "#doc-#{t.name} h2", "/t/#{t.name}")
  end
end
