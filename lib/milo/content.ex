defmodule Milo.Content do
  import Ecto.Query, warn: false
  alias Milo.Repo
  alias Milo.Content.{Category, UserCategory}

  # Categories
  def list_categories do
    Repo.all(from c in Category, order_by: [asc: c.is_default, asc: c.name])
  end

  def get_category!(id), do: Repo.get!(Category, id)
  def get_category_by_name(name), do: Repo.get_by(Category, name: name)

  def create_category(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  def create_default_category!(attrs) do
    create_category(Map.put(attrs, "is_default", true))
  end

  # User <-> Category association
  def list_user_categories(user_id) do
    Repo.all(
      from uc in UserCategory,
        where: uc.user_id == ^user_id,
        join: c in Category, on: c.id == uc.category_id,
        preload: [category: c]
    )
  end

  def list_user_category_ids(user_id) do
    Repo.all(
      from uc in UserCategory,
        where: uc.user_id == ^user_id,
        select: uc.category_id
    )
  end

  def associate_user_category(user_id, category_id) do
    %UserCategory{}
    |> UserCategory.changeset(%{user_id: user_id, category_id: category_id})
    |> Repo.insert(on_conflict: :nothing)
  end

  def dissociate_user_category(user_id, category_id) do
    Repo.delete_all(from uc in UserCategory, where: uc.user_id == ^user_id and uc.category_id == ^category_id)
    :ok
  end

  # convenience: list categories with a flag whether the user has them
  def list_categories_for_user(user_id) do
    selected_ids = list_user_category_ids(user_id) |> MapSet.new()

    Repo.all(from c in Category, order_by: [desc: c.is_default, asc: c.name])
    |> Enum.map(fn c -> Map.put(c, :selected, MapSet.member?(selected_ids, c.id)) end)
  end
end
