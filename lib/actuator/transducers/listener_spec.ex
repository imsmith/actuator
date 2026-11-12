defmodule Actuator.Transducers.ListenerSpec do
  @moduledoc """
  The listener side of Actuator as an OpenAPI 3 document: one `POST /t/{name}`
  path per enabled transducer, so callers can see how to structure requests.

  The request body schema is a free-form object titled with the entry place's
  YANG type. Enforcing that type is tracked in ISSUES.md.
  """

  alias Actuator.Transducers.Transducer

  @doc """
  Builds the document for the given transducers, served under `base_url`.

      iex> source = "cpn-spec 1.0\\nplace inbox -type home:request\\n"
      iex> doc = ListenerSpec.document([%Transducer{name: "lights", source: source, entry_place: "inbox"}], "https://a.example")
      iex> Map.keys(doc["paths"])
      ["/t/lights"]
      iex> get_in(doc, ["paths", "/t/lights", "post", "requestBody", "content", "application/json", "schema", "title"])
      "home:request"
  """
  @spec document([Transducer.t()], String.t()) :: map
  def document(transducers, base_url) do
    %{
      "openapi" => "3.0.3",
      "info" => %{
        "title" => "Actuator listeners",
        "version" => "1",
        "description" =>
          "Each path is a transducer. The JSON body becomes a token on its entry place."
      },
      "servers" => [%{"url" => base_url}],
      "security" => [%{"bearer" => []}],
      "components" => %{
        "securitySchemes" => %{"bearer" => %{"type" => "http", "scheme" => "bearer"}},
        "responses" => %{
          "Accepted" => %{
            "description" => "Token placed on the entry place",
            "content" => %{"application/json" => %{"schema" => accepted_schema()}}
          },
          "Unauthorized" => %{"description" => "Missing or wrong bearer token"},
          "NotFound" => %{"description" => "No running transducer under that name"}
        }
      },
      "paths" => Map.new(transducers, &{"/t/#{&1.name}", path_item(&1)})
    }
  end

  @doc """
  A curl example for one transducer.

      iex> ListenerSpec.curl(%Transducer{name: "lights"}, "https://actuator.example")
      ...> |> String.starts_with?("curl -X POST https://actuator.example/t/lights")
      true
  """
  @spec curl(Transducer.t(), String.t()) :: String.t()
  def curl(%Transducer{name: name}, base_url) do
    ~s|curl -X POST #{base_url}/t/#{name} \\\n  -H "Authorization: Bearer $ACTUATOR_API_TOKEN" \\\n  -H "Content-Type: application/json" \\\n  -d '{"example": "value"}'|
  end

  defp path_item(%Transducer{} = t) do
    place = ExCpn.Net.place(Transducer.net(t), t.entry_place)

    %{
      "post" => %{
        "operationId" => "actuate-#{t.name}",
        "summary" => "Put a token on #{t.entry_place}",
        "description" =>
          "Body is placed as one token on `#{t.entry_place}` (type `#{place.type}`).",
        "requestBody" => %{
          "required" => true,
          "content" => %{
            "application/json" => %{
              "schema" => %{
                "type" => "object",
                "title" => place.type,
                "description" =>
                  "Token for place #{t.entry_place}. Keys are read by `local` guards and bound actions.",
                "additionalProperties" => true
              }
            }
          }
        },
        "responses" => %{
          "202" => %{"$ref" => "#/components/responses/Accepted"},
          "401" => %{"$ref" => "#/components/responses/Unauthorized"},
          "404" => %{"$ref" => "#/components/responses/NotFound"}
        }
      }
    }
  end

  defp accepted_schema do
    %{
      "type" => "object",
      "required" => ["status", "transducer", "place"],
      "properties" => %{
        "status" => %{"type" => "string", "enum" => ["accepted"]},
        "transducer" => %{"type" => "string"},
        "place" => %{"type" => "string"}
      }
    }
  end
end
