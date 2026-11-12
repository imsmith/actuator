defmodule Actuator.Transducers do
  @moduledoc "Transducer definitions: stored `cpn-spec` nets with an entry place."

  import Ecto.Query, warn: false
  alias Actuator.Repo
  alias Actuator.Transducers.{Instances, Transducer}

  @spec list_transducers() :: [Transducer.t()]
  def list_transducers, do: Repo.all(from t in Transducer, order_by: t.name)

  @spec list_enabled() :: [Transducer.t()]
  def list_enabled, do: Repo.all(from t in Transducer, where: t.enabled, order_by: t.name)

  @spec get_transducer!(integer) :: Transducer.t()
  def get_transducer!(id), do: Repo.get!(Transducer, id)

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

  @spec change_transducer(Transducer.t(), map) :: Ecto.Changeset.t()
  def change_transducer(%Transducer{} = t, attrs \\ %{}), do: Transducer.changeset(t, attrs)
end
