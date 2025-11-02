defmodule Milo.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :is_default, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:categories, [:name])
  end
end
