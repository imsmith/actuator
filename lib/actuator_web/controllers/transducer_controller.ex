defmodule ActuatorWeb.TransducerController do
  @moduledoc "Listener: turns a request into a token on a transducer's entry place."
  use ActuatorWeb, :controller

  alias Actuator.Transducers.Instances

  @doc "POST /t/:name — the JSON body becomes the token. 202 on acceptance, 404 if not running."
  def actuate(conn, %{"name" => name} = params) do
    case Instances.lookup_meta(name) do
      {pid, %{entry_place: place}} ->
        :ok = ExCpn.Instance.put_token(pid, place, Map.delete(params, "name"))

        conn
        |> put_status(:accepted)
        |> json(%{status: "accepted", transducer: name, place: place})

      nil ->
        conn |> put_status(:not_found) |> json(%{error: "no running transducer named #{name}"})
    end
  end
end
