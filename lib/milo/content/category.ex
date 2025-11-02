defmodule Milo.Content.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "categories" do
    field :name, :string
    field :description, :string
    field :is_default, :boolean, default: false

    timestamps()
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :description, :is_default])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
