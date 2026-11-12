defmodule Actuator.Transducers.Binding do
  @moduledoc """
  Binds one transition of a transducer to one operation of an API spec. When the
  transition fires, `Actuator.Transducers.Action` performs the operation with the
  consumed token and the response becomes the produced token.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Actuator.ApiSpecs.ApiSpec
  alias Actuator.Transducers.Transducer

  @type t :: %__MODULE__{}

  schema "bindings" do
    field :transition, :string
    field :operation_id, :string
    belongs_to :transducer, Transducer
    belongs_to :api_spec, ApiSpec

    timestamps(type: :utc_datetime)
  end

  @doc "Validates that `transition` is in the transducer's net and `operation_id` is in the spec."
  @spec changeset(t, map, Transducer.t(), ApiSpec.t()) :: Ecto.Changeset.t()
  def changeset(binding, attrs, %Transducer{} = transducer, %ApiSpec{} = spec) do
    binding
    |> cast(attrs, [:transition, :operation_id])
    |> validate_required([:transition, :operation_id])
    |> put_change(:transducer_id, transducer.id)
    |> put_change(:api_spec_id, spec.id)
    |> validate_change(:transition, fn :transition, name ->
      if ExCpn.Net.transition(Transducer.net(transducer), name),
        do: [],
        else: [transition: "is not in the net"]
    end)
    |> validate_change(:operation_id, fn :operation_id, id ->
      if ApiSpec.operation(spec, id), do: [], else: [operation_id: "is not in the spec"]
    end)
    |> unique_constraint([:transducer_id, :transition], message: "is already bound")
  end
end
