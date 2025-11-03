defmodule Milo.Content.UserCategory do
  use Ecto.Schema
  import Ecto.Changeset

  alias Milo.Content.Category

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "user_categories" do
    field :user_id, :binary_id

    belongs_to :category, Category, type: :binary_id

    timestamps()
  end

  def changeset(uc, attrs) do
    uc
    |> cast(attrs, [:user_id, :category_id])
    |> validate_required([:user_id, :category_id])
    |> unique_constraint([:user_id, :category_id], name: :user_categories_user_id_category_id_index)
  end
end
