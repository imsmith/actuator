defmodule Actuator.Transducers.TelemetryTest do
  use ActuatorWeb.ConnCase, async: true

  import Actuator.TransducersFixtures
  alias Actuator.Transducers.Instances

  setup %{conn: conn} do
    t = transducer_fixture()
    on_exit(fn -> Instances.stop(t.name) end)
    test = self()
    handler = "telemetry-test-#{inspect(test)}"

    :telemetry.attach_many(
      handler,
      [
        [:actuator, :transducer, :fired],
        [:actuator, :listener, :accepted],
        [:actuator, :listener, :rejected]
      ],
      fn event, measurements, metadata, _ ->
        send(test, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler) end)
    %{conn: put_req_header(conn, "authorization", "Bearer dev-token"), transducer: t}
  end

  test "listener and firing emit events", %{conn: conn, transducer: t} do
    name = t.name
    post(conn, ~p"/t/#{name}", %{"x" => 1})

    assert_receive {:telemetry, [:actuator, :listener, :accepted], %{count: 1},
                    %{transducer: ^name, place: "inbox"}}

    assert_receive {:telemetry, [:actuator, :transducer, :fired], %{count: 1},
                    %{transducer: ^name, transition: "handle"}}

    post(conn, ~p"/t/ghost", %{})

    assert_receive {:telemetry, [:actuator, :listener, :rejected], _,
                    %{transducer: "ghost", reason: :not_running}}
  end
end
