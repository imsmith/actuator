defmodule ActuatorWeb.ListenerSpecController do
  @moduledoc "Serves the listener OpenAPI document."
  use ActuatorWeb, :controller

  alias Actuator.Transducers
  alias Actuator.Transducers.ListenerSpec

  @doc "GET /t/openapi.json"
  def show(conn, _params) do
    json(conn, ListenerSpec.document(Transducers.list_enabled(), ActuatorWeb.Endpoint.url()))
  end
end
