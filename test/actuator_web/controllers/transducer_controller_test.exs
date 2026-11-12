defmodule ActuatorWeb.TransducerControllerTest do
  use ActuatorWeb.ConnCase, async: true

  import Actuator.TransducersFixtures
  alias Actuator.Transducers.Instances

  setup %{conn: conn} do
    t = transducer_fixture()
    on_exit(fn -> Instances.stop(t.name) end)
    %{conn: put_req_header(conn, "authorization", "Bearer dev-token"), transducer: t}
  end

  test "rejects a missing or wrong token", %{transducer: t} do
    conn = post(build_conn(), ~p"/t/#{t.name}", %{})
    assert json_response(conn, 401)["error"] == "unauthorized"

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer nope")
      |> post(~p"/t/#{t.name}", %{})

    assert json_response(conn, 401)
  end

  test "404 for a transducer that is not running", %{conn: conn} do
    conn = post(conn, ~p"/t/ghost", %{})
    assert json_response(conn, 404)["error"] =~ "ghost"
  end

  test "accepts a request and the body lands as a token", %{conn: conn, transducer: t} do
    conn = post(conn, ~p"/t/#{t.name}", %{"device" => "lamp-1", "state" => "on"})
    assert %{"status" => "accepted", "place" => "inbox"} = json_response(conn, 202)
    marking = ExCpn.Instance.await_quiescent(Instances.via(t.name))
    assert marking["done"] == [%{"device" => "lamp-1", "state" => "on"}]
  end
end
