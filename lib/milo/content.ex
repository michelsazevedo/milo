defmodule Milo.Content do
  import Ecto.Query, warn: false
  alias Milo.Repo
  alias Milo.Content.{Category, UserCategory}

  # Categories
  def list_categories do
    Repo.all(from c in Category, order_by: [asc: c.is_default, asc: c.name])
  end

  def get_category_by_name(name) do
    Repo.get_by(Category, name: name)
  end

  def create_category(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
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
    case Repo.insert(
           %UserCategory{}
           |> UserCategory.changeset(%{user_id: user_id, category_id: category_id}),
           on_conflict: :nothing
         ) do
      {:ok, _user_category} -> :ok
      {:error, _changeset} = error -> error
    end
  end

  def dissociate_user_category(user_id, category_id) do
    Repo.delete_all(from uc in UserCategory, where: uc.user_id == ^user_id and uc.category_id == ^category_id)
    :ok
  end
end
