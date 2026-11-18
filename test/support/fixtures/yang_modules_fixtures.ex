defmodule Actuator.YangModulesFixtures do
  @moduledoc "Test fixtures for `Actuator.YangModules`."

  @source """
  module home {
    namespace "urn:home";
    prefix hm;
    container request {
      leaf id { type string; }
      leaf state { type string; }
    }
    typedef level { type uint8; }
  }
  """

  @spec valid_yang() :: String.t()
  def valid_yang, do: @source

  @spec yang_module_fixture(map) :: Actuator.YangModules.YangModule.t()
  def yang_module_fixture(attrs \\ %{}) do
    {:ok, m} =
      attrs |> Enum.into(%{source: @source}) |> Actuator.YangModules.create_yang_module()

    m
  end
end
