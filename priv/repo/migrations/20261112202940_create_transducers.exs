defmodule Actuator.Repo.Migrations.CreateTransducers do
  use Ecto.Migration

  def change do
    create table(:transducers) do
      add :name, :string, null: false
      add :source, :text, null: false
      add :entry_place, :string, null: false
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:transducers, [:name])
  end
end
