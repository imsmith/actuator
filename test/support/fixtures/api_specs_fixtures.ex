defmodule Actuator.ApiSpecsFixtures do
  @moduledoc "Test fixtures for `Actuator.ApiSpecs`."

  @yaml """
  openapi: 3.0.3
  info: {title: Lights, version: "1"}
  servers:
    - url: http://lights.local/api
  paths:
    /devices/{id}/state:
      put:
        operationId: setState
        summary: Set a device's state
    /devices:
      get:
        operationId: listDevices
  """

  @spec valid_yaml() :: String.t()
  def valid_yaml, do: @yaml

  @spec valid_json() :: String.t()
  def valid_json do
    Jason.encode!(%{
      "openapi" => "3.1.0",
      "info" => %{"title" => "Ping", "version" => "1"},
      "paths" => %{"/ping" => %{"post" => %{"operationId" => "ping"}}}
    })
  end

  @spec api_spec_fixture(map) :: Actuator.ApiSpecs.ApiSpec.t()
  def api_spec_fixture(attrs \\ %{}) do
    {:ok, spec} =
      attrs
      |> Enum.into(%{name: "spec-#{System.unique_integer([:positive])}", source: @yaml})
      |> Actuator.ApiSpecs.create_api_spec()

    spec
  end
end
