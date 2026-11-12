defmodule Actuator.Transducers.ActionTest do
  # Req.Test stubs are shared with the instance's task process, so not async.
  use Actuator.DataCase, async: false

  import Actuator.ApiSpecsFixtures
  import Actuator.TransducersFixtures
  alias Actuator.ApiSpecs.ApiSpec
  alias Actuator.Transducers
  alias Actuator.Transducers.{Action, Instances}

  setup do
    Req.Test.set_req_test_to_shared(%{})
    on_exit(fn -> Req.Test.set_req_test_to_private(%{}) end)
    :ok
  end

  test "PUT fills path params, sends the rest as JSON, carries the auth header, produces the response" do
    spec = api_spec_fixture(%{auth_header: "Bearer s3cret"})
    op = ApiSpec.operation(spec, "setState")
    test = self()

    Req.Test.stub(Action, fn conn ->
      send(
        test,
        {:request, conn.method, conn.request_path,
         Plug.Conn.get_req_header(conn, "authorization"), conn.body_params}
      )

      Req.Test.json(conn, %{"ok" => true})
    end)

    assert {:ok, produced} =
             Action.perform(spec, op, %{"id" => "lamp-1", "state" => "on"}, ["done"])

    assert_received {:request, "PUT", "/api/devices/lamp-1/state", ["Bearer s3cret"],
                     %{"state" => "on"}}

    assert produced == %{
             "done" => %{
               "id" => "lamp-1",
               "state" => "on",
               "status" => 200,
               "response" => %{"ok" => true}
             }
           }
  end

  test "GET sends the token as query params; non-2xx is an error" do
    spec = api_spec_fixture()
    op = ApiSpec.operation(spec, "listDevices")
    test = self()

    Req.Test.stub(Action, fn conn ->
      send(test, {:query, conn.query_string})
      conn |> Plug.Conn.put_status(503) |> Req.Test.json(%{"error" => "down"})
    end)

    assert {:error, {:http, 503, %{"error" => "down"}}} =
             Action.perform(spec, op, %{"room" => "den"}, [])

    assert_received {:query, "room=den"}
  end

  test "a bound transition calls the API when it fires and the response lands downstream" do
    spec = api_spec_fixture()
    t = transducer_fixture()
    on_exit(fn -> Instances.stop(t.name) end)

    Req.Test.stub(Action, fn conn -> Req.Test.json(conn, %{"applied" => true}) end)
    assert {:ok, _} = Transducers.bind(t, "handle", spec, "setState")

    pid = Instances.lookup(t.name)
    :ok = ExCpn.Instance.put_token(pid, "inbox", %{"id" => "lamp-9"})
    marking = ExCpn.Instance.await_quiescent(pid)

    assert [%{"id" => "lamp-9", "status" => 200, "response" => %{"applied" => true}}] =
             marking["done"]
  end

  test "binding validates transition and operation; unbind restarts without the action" do
    spec = api_spec_fixture()
    t = transducer_fixture()
    on_exit(fn -> Instances.stop(t.name) end)

    assert {:error, cs} = Transducers.bind(t, "nope", spec, "setState")
    assert %{transition: ["is not in the net"]} = errors_on(cs)
    assert {:error, cs} = Transducers.bind(t, "handle", spec, "nope")
    assert %{operation_id: ["is not in the spec"]} = errors_on(cs)

    {:ok, binding} = Transducers.bind(t, "handle", spec, "setState")
    assert {:error, cs} = Transducers.bind(t, "handle", spec, "listDevices")
    assert %{transducer_id: ["is already bound"]} = errors_on(cs)

    assert [%{transition: "handle", api_spec: %{id: _}}] = Transducers.list_bindings(t)
    {:ok, _} = Transducers.unbind(binding)
    assert Transducers.list_bindings(t) == []
    assert Instances.lookup(t.name)
  end
end
