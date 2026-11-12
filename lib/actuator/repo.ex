defmodule Actuator.Repo do
  @moduledoc "Ecto repo on SQLite. The prototype keeps everything in one file."
  use Ecto.Repo,
    otp_app: :actuator,
    adapter: Ecto.Adapters.SQLite3
end
