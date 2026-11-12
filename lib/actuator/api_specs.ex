defmodule Actuator.ApiSpecs do
  @moduledoc "Stored OpenAPI 3 documents that transducer actions call."

  import Ecto.Query, warn: false
  alias Actuator.ApiSpecs.ApiSpec
  alias Actuator.Repo

  @doc "All specs by name."
  @spec list_api_specs() :: [ApiSpec.t()]
  def list_api_specs, do: Repo.all(from s in ApiSpec, order_by: s.name)

  @doc "Fetches by id; raises when missing."
  @spec get_api_spec!(integer) :: ApiSpec.t()
  def get_api_spec!(id), do: Repo.get!(ApiSpec, id)

  @doc "Fetches by name, or `nil`."
  @spec get_by_name(String.t()) :: ApiSpec.t() | nil
  def get_by_name(name), do: Repo.get_by(ApiSpec, name: name)

  @doc "Creates a spec. The document is validated by `Actuator.ApiSpecs.ApiSpec.changeset/2`."
  @spec create_api_spec(map) :: {:ok, ApiSpec.t()} | {:error, Ecto.Changeset.t()}
  def create_api_spec(attrs), do: %ApiSpec{} |> ApiSpec.changeset(attrs) |> Repo.insert()

  @doc "Updates a spec. Running instances keep the old action until their transducer is synced."
  @spec update_api_spec(ApiSpec.t(), map) :: {:ok, ApiSpec.t()} | {:error, Ecto.Changeset.t()}
  def update_api_spec(%ApiSpec{} = spec, attrs),
    do: spec |> ApiSpec.changeset(attrs) |> Repo.update()

  @doc "Deletes a spec and, by cascade, its bindings. See ISSUES.md."
  @spec delete_api_spec(ApiSpec.t()) :: {:ok, ApiSpec.t()} | {:error, Ecto.Changeset.t()}
  def delete_api_spec(%ApiSpec{} = spec), do: Repo.delete(spec)

  @doc "Changeset for forms."
  @spec change_api_spec(ApiSpec.t(), map) :: Ecto.Changeset.t()
  def change_api_spec(%ApiSpec{} = spec, attrs \\ %{}), do: ApiSpec.changeset(spec, attrs)

  @doc "Every operation of every spec as `{spec, operation}`, for binding pickers."
  @spec all_operations() :: [{ApiSpec.t(), ApiSpec.operation()}]
  def all_operations do
    for spec <- list_api_specs(), op <- ApiSpec.operations(spec), do: {spec, op}
  end
end
