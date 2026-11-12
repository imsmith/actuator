defmodule Actuator.ApiSpecsTest do
  use Actuator.DataCase, async: true

  import Actuator.ApiSpecsFixtures
  alias Actuator.ApiSpecs
  alias Actuator.ApiSpecs.ApiSpec

  test "stores YAML, fills base_url from servers, lists operations" do
    spec = api_spec_fixture(%{name: "lights"})
    assert spec.base_url == "http://lights.local/api"

    assert [
             %{id: "listDevices", method: "get", path: "/devices", summary: ""},
             %{
               id: "setState",
               method: "put",
               path: "/devices/{id}/state",
               summary: "Set a device's state"
             }
           ] = ApiSpec.operations(spec)

    assert ApiSpec.operation(spec, "setState").method == "put"
    assert [{%ApiSpec{name: "lights"}, _} | _] = ApiSpecs.all_operations()
  end

  test "stores JSON and keeps an explicit base_url" do
    spec = api_spec_fixture(%{source: valid_json(), base_url: "http://ping.local"})
    assert spec.base_url == "http://ping.local"
    assert [%{id: "ping", method: "post"}] = ApiSpec.operations(spec)
  end

  test "rejects non-OpenAPI-3 documents" do
    for {source, msg} <- [
          {"{\"swagger\": \"2.0\"}", "Swagger 2.0"},
          {"{\"openapi\": \"3.0.0\"}", "paths must be an object"},
          {"just: yaml", "missing openapi version"},
          {"[1, 2]", "document must be"},
          {"{not json: [", "not JSON, and YAML failed"}
        ] do
      assert {:error, cs} = ApiSpecs.create_api_spec(%{name: "x", source: source})
      assert %{source: [got]} = errors_on(cs), source
      assert got =~ msg, "#{source} -> #{got}"
    end
  end

  test "names are unique and lowercase" do
    api_spec_fixture(%{name: "dup"})
    assert {:error, cs} = ApiSpecs.create_api_spec(%{name: "dup", source: valid_yaml()})
    assert %{name: ["has already been taken"]} = errors_on(cs)
    assert {:error, cs} = ApiSpecs.create_api_spec(%{name: "Dup", source: valid_yaml()})
    assert %{name: [_]} = errors_on(cs)
  end
end
