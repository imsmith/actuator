defmodule Actuator.TransducersFixtures do
  @moduledoc "Test fixtures for `Actuator.Transducers`."

  @source """
  cpn-spec 1.0
  place inbox -type m:request
  place done  -type m:request
  transition handle {
    in  {inbox r}
    out {done $r}
  }
  """

  @spec valid_source() :: String.t()
  def valid_source, do: @source

  @spec transducer_fixture(map) :: Actuator.Transducers.Transducer.t()
  def transducer_fixture(attrs \\ %{}) do
    {:ok, transducer} =
      attrs
      |> Enum.into(%{
        name: "t-#{System.unique_integer([:positive])}",
        source: @source,
        entry_place: "inbox"
      })
      |> Actuator.Transducers.create_transducer()

    transducer
  end
end
