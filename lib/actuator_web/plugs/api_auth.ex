defmodule ActuatorWeb.Plugs.ApiAuth do
  @moduledoc """
  Bearer-token check for the listener API. The single admin token comes from
  `config :actuator, :api_token`. Missing or wrong token is a JSON 401.
  """

  import Plug.Conn
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    expected = Application.fetch_env!(:actuator, :api_token)

    with ["Bearer " <> given] <- get_req_header(conn, "authorization"),
         true <- Plug.Crypto.secure_compare(given, expected) do
      conn
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "unauthorized"})
        |> halt()
    end
  end
end
