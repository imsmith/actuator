defmodule Actuator.Repo do
  use Ecto.Repo,
    otp_app: :actuator,
    adapter: Ecto.Adapters.SQLite3
end
