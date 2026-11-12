defmodule Actuator.Repo.Migrations.CreateApiSpecs do
  use Ecto.Migration

  def change do
    create table(:api_specs) do
      add :name, :string, null: false
      add :source, :text, null: false
      add :base_url, :string
      add :auth_header, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:api_specs, [:name])
  end
end
