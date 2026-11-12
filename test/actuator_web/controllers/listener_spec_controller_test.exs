defmodule ActuatorWeb.ListenerSpecControllerTest do
  use ActuatorWeb.ConnCase, async: true

  import Actuator.TransducersFixtures
  alias Actuator.Transducers.Instances

  setup %{conn: conn} do
    t = transducer_fixture(%{name: "lights"})
    off = transducer_fixture(%{name: "dark", enabled: false})
    on_exit(fn -> Instances.stop(t.name) end)

    %{
      conn: put_req_header(conn, "authorization", "Bearer dev-token"),
      transducer: t,
      disabled: off
    }
  end

  test "needs the bearer token" do
    assert get(build_conn(), ~p"/t/openapi.json").status == 401
  end

  test "describes every enabled transducer as a POST path", %{conn: conn} do
    doc = conn |> get(~p"/t/openapi.json") |> json_response(200)
    assert doc["openapi"] == "3.0.3"
    assert %{"post" => %{"operationId" => "actuate-lights"} = op} = doc["paths"]["/t/lights"]
    refute Map.has_key?(doc["paths"], "/t/dark")
    assert op["requestBody"]["content"]["application/json"]["schema"]["title"] == "m:request"
    assert op["responses"]["202"]["$ref"] == "#/components/responses/Accepted"
    assert doc["security"] == [%{"bearer" => []}]
    assert [%{"url" => "http://" <> _}] = doc["servers"]
  end
end
