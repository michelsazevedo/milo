defmodule Milo.Repo.Migrations.CreateUserCategories do
  use Ecto.Migration

  def change do
    create table(:user_categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :category_id, references(:categories, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:user_categories, [:user_id, :category_id])
    create index(:user_categories, [:category_id])
  end
end
