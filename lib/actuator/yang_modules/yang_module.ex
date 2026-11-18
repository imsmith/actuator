defmodule Actuator.YangModules.YangModule do
  @moduledoc """
  A YANG module stored as given. `name` and `prefix` are read from the parsed
  source, not entered. Transducer place types (`prefix:node`) resolve against
  the modules a net imports; see `Actuator.YangModules.resolve/2`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "yang_modules" do
    field :name, :string
    field :prefix, :string
    field :source, :string

    timestamps(type: :utc_datetime)
  end

  @doc "Validates that `source` parses with `ExYang` and fills `name` and `prefix` from it."
  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(mod, attrs) do
    mod
    |> cast(attrs, [:source])
    |> validate_required([:source])
    |> parse_source()
    |> unique_constraint(:name)
  end

  @doc "Parses the stored source. Raises if it does not parse; the changeset guarantees it does."
  @spec module(t) :: ExYang.Model.Module.t()
  def module(%__MODULE__{source: source}), do: ExYang.parse!(source)

  @doc """
  Names a place type may refer to: top-level data nodes, typedefs, and groupings.

      iex> {:ok, m} = ExYang.parse("module m { namespace \\"urn:m\\"; prefix m; container request { leaf id { type string; } } typedef state { type string; } }")
      iex> YangModule.node_names(m)
      ["request", "state"]
  """
  @spec node_names(ExYang.Model.Module.t()) :: [String.t()]
  def node_names(%ExYang.Model.Module{} = m) do
    (m.body ++ m.typedefs ++ m.groupings) |> Enum.map(& &1.name) |> Enum.sort()
  end

  defp parse_source(changeset) do
    with source when is_binary(source) <- get_change(changeset, :source),
         {:ok, %ExYang.Model.Module{name: name, prefix: prefix}} when is_binary(name) <-
           ExYang.parse(source) do
      changeset
      |> put_change(:name, name)
      |> put_change(:prefix, prefix || name)
    else
      nil -> changeset
      {:ok, _} -> add_error(changeset, :source, "must be a module, not a submodule")
      {:error, reason} -> add_error(changeset, :source, format(reason))
    end
  end

  defp format(reason) when is_binary(reason), do: reason
  defp format(%{message: m}), do: m
  defp format(reason), do: inspect(reason)
end
