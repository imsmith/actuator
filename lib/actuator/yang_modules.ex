defmodule Actuator.YangModules do
  @moduledoc "Stored YANG modules that transducer place types resolve against."

  import Ecto.Query, warn: false
  alias Actuator.Repo
  alias Actuator.YangModules.YangModule

  @doc "All modules by name."
  @spec list_yang_modules() :: [YangModule.t()]
  def list_yang_modules, do: Repo.all(from m in YangModule, order_by: m.name)

  @doc "Fetches by id; raises when missing."
  @spec get_yang_module!(integer | String.t()) :: YangModule.t()
  def get_yang_module!(id), do: Repo.get!(YangModule, id)

  @doc "Fetches by module name, or `nil`."
  @spec get_by_name(String.t()) :: YangModule.t() | nil
  def get_by_name(name), do: Repo.get_by(YangModule, name: name)

  @spec create_yang_module(map) :: {:ok, YangModule.t()} | {:error, Ecto.Changeset.t()}
  def create_yang_module(attrs), do: %YangModule{} |> YangModule.changeset(attrs) |> Repo.insert()

  @spec update_yang_module(YangModule.t(), map) ::
          {:ok, YangModule.t()} | {:error, Ecto.Changeset.t()}
  def update_yang_module(%YangModule{} = m, attrs),
    do: m |> YangModule.changeset(attrs) |> Repo.update()

  @spec delete_yang_module(YangModule.t()) :: {:ok, YangModule.t()} | {:error, Ecto.Changeset.t()}
  def delete_yang_module(%YangModule{} = m), do: Repo.delete(m)

  @spec change_yang_module(YangModule.t(), map) :: Ecto.Changeset.t()
  def change_yang_module(%YangModule{} = m, attrs \\ %{}), do: YangModule.changeset(m, attrs)

  @doc """
  Checks every typed place in `net` against the modules it imports. Each
  `prefix:node` must name a module in `net.imports` (by prefix or name) with
  a top-level node, typedef, or grouping called `node`. Returns one message
  per problem, in place order. A net with no imports is not checked.
  """
  @spec resolve(ExCpn.Net.t()) :: [String.t()]
  def resolve(%ExCpn.Net{imports: []}), do: []

  def resolve(%ExCpn.Net{imports: imports, places: places}) do
    stored = Repo.all(from m in YangModule, where: m.name in ^imports)
    missing = imports -- Enum.map(stored, & &1.name)

    by_prefix =
      Map.new(stored, fn m ->
        {m.prefix, {m.name, YangModule.node_names(YangModule.module(m))}}
      end)

    by_name = Map.new(stored, fn m -> {m.name, by_prefix[m.prefix]} end)

    import_errors = Enum.map(missing, &"yang import #{&1}: no stored module with that name")

    place_errors =
      for %{name: place, type: type} when is_binary(type) <- places,
          msg = place_error(place, type, Map.merge(by_name, by_prefix)),
          do: msg

    import_errors ++ place_errors
  end

  defp place_error(place, type, mods) do
    case String.split(type, ":", parts: 2) do
      [prefix, node] -> node_error(place, type, prefix, node, mods[prefix])
      _ -> "place #{place}: type #{type} is not prefix:node"
    end
  end

  defp node_error(place, type, _prefix, _node, nil),
    do: "place #{place}: type #{type} names no imported module"

  defp node_error(place, _type, prefix, node, {_, nodes}),
    do: if(node in nodes, do: nil, else: "place #{place}: #{node} is not in #{prefix}")
end
