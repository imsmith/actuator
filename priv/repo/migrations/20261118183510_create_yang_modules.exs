defmodule Actuator.Repo.Migrations.CreateYangModules do
  use Ecto.Migration

  def change do
    create table(:yang_modules) do
      add :name, :string, null: false
      add :prefix, :string, null: false
      add :source, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:yang_modules, [:name])
  end
end
