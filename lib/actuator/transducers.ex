defmodule Actuator.Transducers do
  @moduledoc "Transducer definitions: stored `cpn-spec` nets with an entry place."

  import Ecto.Query, warn: false
  alias Actuator.Repo
  alias Actuator.ApiSpecs.ApiSpec
  alias Actuator.Transducers.{Binding, Instances, Transducer}

  @doc "All definitions by name."
  @spec list_transducers() :: [Transducer.t()]
  def list_transducers, do: Repo.all(from t in Transducer, order_by: t.name)

  @doc "Definitions that should be running."
  @spec list_enabled() :: [Transducer.t()]
  def list_enabled, do: Repo.all(from t in Transducer, where: t.enabled, order_by: t.name)

  @doc "Fetches by id; raises when missing."
  @spec get_transducer!(integer) :: Transducer.t()
  def get_transducer!(id), do: Repo.get!(Transducer, id)

  @doc "Fetches by name, or `nil`."
  @spec get_by_name(String.t()) :: Transducer.t() | nil
  def get_by_name(name), do: Repo.get_by(Transducer, name: name)

  @doc "Creates a definition and starts its instance when enabled."
  @spec create_transducer(map) :: {:ok, Transducer.t()} | {:error, Ecto.Changeset.t()}
  def create_transducer(attrs) do
    %Transducer{} |> Transducer.changeset(attrs) |> Repo.insert() |> synced()
  end

  @doc "Updates a definition and restarts (or stops) its instance to match."
  @spec update_transducer(Transducer.t(), map) ::
          {:ok, Transducer.t()} | {:error, Ecto.Changeset.t()}
  def update_transducer(%Transducer{} = t, attrs) do
    t |> Transducer.changeset(attrs) |> Repo.update() |> synced()
  end

  @doc "Deletes a definition and stops its instance."
  @spec delete_transducer(Transducer.t()) :: {:ok, Transducer.t()} | {:error, Ecto.Changeset.t()}
  def delete_transducer(%Transducer{} = t) do
    with {:ok, deleted} <- Repo.delete(t) do
      :ok = Instances.stop(deleted.name)
      {:ok, deleted}
    end
  end

  defp synced({:ok, t}) do
    :ok = Instances.sync(t)
    {:ok, t}
  end

  defp synced(err), do: err

  @doc "Bindings for a transducer with `api_spec` loaded, in transition order."
  @spec list_bindings(Transducer.t()) :: [Binding.t()]
  def list_bindings(%Transducer{id: id}) do
    Repo.all(
      from b in Binding, where: b.transducer_id == ^id, order_by: b.transition, preload: :api_spec
    )
  end

  @doc "Binds a transition to an operation and restarts the instance so the action takes effect."
  @spec bind(Transducer.t(), String.t(), ApiSpec.t(), String.t()) ::
          {:ok, Binding.t()} | {:error, Ecto.Changeset.t()}
  def bind(%Transducer{} = t, transition, %ApiSpec{} = spec, operation_id) do
    attrs = %{transition: transition, operation_id: operation_id}

    with {:ok, binding} <- %Binding{} |> Binding.changeset(attrs, t, spec) |> Repo.insert() do
      :ok = Instances.sync(t)
      {:ok, %{binding | api_spec: spec}}
    end
  end

  @doc "Removes a binding and restarts the instance."
  @spec unbind(Binding.t()) :: {:ok, Binding.t()} | {:error, Ecto.Changeset.t()}
  def unbind(%Binding{} = binding) do
    with {:ok, deleted} <- Repo.delete(binding) do
      :ok = Instances.sync(get_transducer!(binding.transducer_id))
      {:ok, deleted}
    end
  end

  @doc "Changeset for forms."
  @spec change_transducer(Transducer.t(), map) :: Ecto.Changeset.t()
  def change_transducer(%Transducer{} = t, attrs \\ %{}), do: Transducer.changeset(t, attrs)
end
