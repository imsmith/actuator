defmodule Actuator.Repo.Migrations.CreateBindings do
  use Ecto.Migration

  def change do
    create table(:bindings) do
      add :transducer_id, references(:transducers, on_delete: :delete_all), null: false
      add :transition, :string, null: false
      add :api_spec_id, references(:api_specs, on_delete: :delete_all), null: false
      add :operation_id, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bindings, [:transducer_id, :transition])
    create index(:bindings, [:api_spec_id])
  end
end
