defmodule Milo.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Milo.Repo

  alias Milo.Accounts.User

  def get_or_create_user_from_google(%{"email" => email} = attrs) do
    case Repo.get_by(User, email: email) do
      nil ->
        %User{}
        |> User.changeset(%{email: email, name: attrs["name"], google_token: attrs["google_token"]})
        |> Repo.insert()

      user ->
        user
        |> User.changeset(%{google_token: attrs["google_token"], name: attrs["name"]})
        |> Repo.update()
    end
  end

  def get_user!(id) do
    Repo.get!(User, id)
  end
end
