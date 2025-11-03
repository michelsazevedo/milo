defmodule Milo.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Milo.Repo

  alias Milo.Accounts.User
  alias Milo.Gmail.Watcher

  def get_or_create_user_from_google(%{"email" => email} = attrs) do
    case Repo.get_by(User, email: email) do
      nil ->
        case %User{}
             |> User.changeset(%{email: email, name: attrs["name"], google_token: attrs["google_token"]})
             |> Repo.insert() do
          {:ok, user} ->
            Watcher.register_watch(user)
            {:ok, user}

          {:error, changeset} ->
            {:error, changeset}
        end

      user ->
        user
        |> User.changeset(%{google_token: attrs["google_token"], name: attrs["name"]})
        |> Repo.update()
    end
  end

  def get_user!(id) do
    Repo.get!(User, id)
  end

  def get_user_by_email(email) do
    case Repo.get_by(User, email: email) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end
end
