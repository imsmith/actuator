defmodule Actuator.Repo do
  use Ecto.Repo,
    otp_app: :actuator,
    adapter: Ecto.Adapters.Postgres
end
