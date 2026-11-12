defmodule Actuator.Transducers.Action do
  @moduledoc """
  Turns a binding into an `ExCpn.Instance` action that performs the bound
  OpenAPI operation with Req.

  Request shape, from the consumed token (the first `in` variable's value):

    * `{param}` segments in the path are filled from token keys of the same name
    * remaining keys go in the query for GET, DELETE, HEAD, OPTIONS, and in the
      JSON body otherwise
    * the spec's `auth_header`, when set, is sent verbatim as `Authorization`

  A 2xx response produces, for every out place, the token merged with
  `"status"` and `"response"` (the decoded body). Anything else is
  `{:error, {:http, status, body}}` or `{:error, {:transport, reason}}`.
  """

  alias Actuator.ApiSpecs.ApiSpec
  alias Actuator.Transducers.Binding
  alias ExCpn.Net.Transition

  @query_methods ~w(get delete head options)

  @doc "Builds the action for a binding whose `api_spec` is loaded."
  @spec build(Binding.t(), Transition.t()) :: ExCpn.Instance.action()
  def build(%Binding{api_spec: %ApiSpec{} = spec} = binding, %Transition{} = transition) do
    op =
      ApiSpec.operation(spec, binding.operation_id) ||
        raise ArgumentError, "unknown operation #{binding.operation_id}"

    in_var =
      case transition.in do
        [arc | _] -> arc.expr
        [] -> nil
      end

    out_places = Enum.map(transition.out, & &1.place)

    fn _name, bound ->
      token = if in_var, do: Map.get(bound, in_var, %{}), else: %{}
      perform(spec, op, token, out_places)
    end
  end

  @doc "Performs the operation. Public so it can be tested without an instance."
  @spec perform(ApiSpec.t(), ApiSpec.operation(), map, [String.t()]) ::
          {:ok, map} | {:error, term}
  def perform(%ApiSpec{} = spec, op, token, out_places) do
    {path, rest} = fill_path(op.path, token)
    method = String.to_existing_atom(op.method)

    req =
      [method: method, url: (spec.base_url || "") <> path, headers: auth(spec), retry: false]
      |> Keyword.merge(payload(op.method, rest))
      |> Keyword.merge(Application.get_env(:actuator, :req_options, []))
      |> Req.new()

    case Req.request(req) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        produced = Map.merge(token, %{"status" => status, "response" => body})
        {:ok, Map.new(out_places, &{&1, produced})}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http, status, body}}

      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  defp fill_path(path, token) do
    Regex.scan(~r/\{([^}]+)\}/, path)
    |> Enum.reduce({path, token}, fn [whole, key], {p, t} ->
      {String.replace(p, whole, to_string(Map.get(t, key, ""))), Map.delete(t, key)}
    end)
  end

  defp payload(method, rest) when method in @query_methods, do: [params: rest]
  defp payload(_method, rest), do: [json: rest]

  defp auth(%ApiSpec{auth_header: nil}), do: []
  defp auth(%ApiSpec{auth_header: ""}), do: []
  defp auth(%ApiSpec{auth_header: h}), do: [authorization: h]
end
