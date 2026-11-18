defmodule Actuator.Transducers.Transducer do
  @moduledoc """
  A transducer definition: a named `cpn-spec` net, the place that inbound
  requests land on, and an enabled flag. `source` is validated with `ExCpn`
  on every change; `net/1` gives the parsed form.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "transducers" do
    field :name, :string
    field :source, :string
    field :entry_place, :string
    field :enabled, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @name_format ~r/^[a-z0-9][a-z0-9-]*$/

  @doc """
  Validates name, source (parse + `ExCpn.validate/1`), that place types resolve
  against imported YANG modules (`Actuator.YangModules.resolve/1`), and that
  `entry_place` exists in the net.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(transducer, attrs) do
    transducer
    |> cast(attrs, [:name, :source, :entry_place, :enabled])
    |> validate_required([:name, :source, :entry_place])
    |> validate_format(:name, @name_format,
      message: "must be lowercase letters, digits, and dashes"
    )
    |> validate_length(:name, max: 64)
    |> validate_net()
    |> unique_constraint(:name)
  end

  @doc "Parses the stored source. Raises if it does not parse; the changeset guarantees it does."
  @spec net(t) :: ExCpn.Net.t()
  def net(%__MODULE__{source: source}) do
    {:ok, net} = ExCpn.parse(source)
    net
  end

  defp validate_net(changeset) do
    with source when is_binary(source) <- get_field(changeset, :source),
         {:ok, net} <- ExCpn.parse(source),
         {:ok, net} <- ExCpn.validate(net),
         [] <- Actuator.YangModules.resolve(net) do
      validate_entry_place(changeset, net)
    else
      nil ->
        changeset

      {:error, {line, msg}} ->
        add_error(changeset, :source, "line #{line}: #{msg}")

      {:error, problems} ->
        Enum.reduce(problems, changeset, &add_problem/2)

      unresolved when is_list(unresolved) ->
        Enum.reduce(unresolved, changeset, &add_error(&2, :source, &1))
    end
  end

  defp add_problem({:error, msg}, changeset), do: add_error(changeset, :source, msg)
  defp add_problem({:warning, _}, changeset), do: changeset

  defp validate_entry_place(changeset, net) do
    case get_field(changeset, :entry_place) do
      nil ->
        changeset

      place ->
        if ExCpn.Net.place(net, place),
          do: changeset,
          else: add_error(changeset, :entry_place, "is not a place in the net")
    end
  end
end
