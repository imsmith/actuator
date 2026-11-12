defmodule Actuator.ApiSpecs.ApiSpec do
  @moduledoc """
  An OpenAPI 3 document stored as given (JSON or YAML) plus the connection
  details a client needs: `base_url` (defaults to the spec's first server) and
  an optional `auth_header` sent verbatim as `Authorization`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @typedoc "One operation from `paths`."
  @type operation :: %{id: String.t(), method: String.t(), path: String.t(), summary: String.t()}

  schema "api_specs" do
    field :name, :string
    field :source, :string
    field :base_url, :string
    field :auth_header, :string, redact: true

    timestamps(type: :utc_datetime)
  end

  @name_format ~r/^[a-z0-9][a-z0-9-]*$/
  @methods ~w(get put post delete options head patch trace)

  @doc "Validates name, that `source` is an OpenAPI 3 document with paths, and fills `base_url` from the spec when blank."
  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(spec, attrs) do
    spec
    |> cast(attrs, [:name, :source, :base_url, :auth_header])
    |> validate_required([:name, :source])
    |> validate_format(:name, @name_format,
      message: "must be lowercase letters, digits, and dashes"
    )
    |> validate_document()
    |> unique_constraint(:name)
  end

  @doc "Decodes the stored source. JSON first, then YAML."
  @spec decode(String.t()) :: {:ok, map} | {:error, String.t()}
  def decode(source) do
    case Jason.decode(source) do
      {:ok, %{} = doc} ->
        {:ok, doc}

      {:ok, _} ->
        {:error, "document must be an object"}

      {:error, _} ->
        case YamlElixir.read_from_string(source) do
          {:ok, %{} = doc} -> {:ok, doc}
          {:ok, _} -> {:error, "document must be a mapping"}
          {:error, %{message: m}} -> {:error, "not JSON, and YAML failed: #{m}"}
          {:error, other} -> {:error, "not JSON, and YAML failed: #{inspect(other)}"}
        end
    end
  end

  @doc "The decoded document. Raises if it does not decode; the changeset guarantees it does."
  @spec document(t) :: map
  def document(%__MODULE__{source: source}) do
    {:ok, doc} = decode(source)
    doc
  end

  @doc "Operations in path order. `id` is `operationId` or `METHOD path` when absent."
  @spec operations(t | map) :: [operation]
  def operations(%__MODULE__{} = spec), do: spec |> document() |> operations()

  def operations(%{"paths" => paths}) when is_map(paths) do
    for {path, item} <- Enum.sort(paths),
        is_map(item),
        {method, op} <- Enum.sort(item),
        method in @methods,
        is_map(op) do
      %{
        id: op["operationId"] || "#{String.upcase(method)} #{path}",
        method: method,
        path: path,
        summary: op["summary"] || op["description"] || ""
      }
    end
  end

  def operations(_), do: []

  @spec operation(t, String.t()) :: operation | nil
  def operation(%__MODULE__{} = spec, id), do: spec |> operations() |> Enum.find(&(&1.id == id))

  defp validate_document(changeset) do
    with source when is_binary(source) <- get_field(changeset, :source),
         {:ok, doc} <- decode(source),
         :ok <- check_openapi(doc) do
      default_base_url(changeset, doc)
    else
      nil -> changeset
      {:error, msg} -> add_error(changeset, :source, msg)
    end
  end

  defp check_openapi(%{"openapi" => "3." <> _, "paths" => paths}) when is_map(paths), do: :ok
  defp check_openapi(%{"openapi" => "3." <> _}), do: {:error, "paths must be an object"}

  defp check_openapi(%{"openapi" => v}),
    do: {:error, "only OpenAPI 3.x is supported, got #{inspect(v)}"}

  defp check_openapi(%{"swagger" => _}),
    do: {:error, "Swagger 2.0 is not supported; convert to OpenAPI 3"}

  defp check_openapi(_), do: {:error, "missing openapi version"}

  defp default_base_url(changeset, doc) do
    case {get_field(changeset, :base_url), doc} do
      {nil, %{"servers" => [%{"url" => url} | _]}} -> put_change(changeset, :base_url, url)
      {"", %{"servers" => [%{"url" => url} | _]}} -> put_change(changeset, :base_url, url)
      _ -> changeset
    end
  end
end
