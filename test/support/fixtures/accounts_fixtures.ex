defmodule Milo.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Milo.Accounts` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        "email" => "some email",
        "google_token" => "some google_token",
        "name" => "some name"
      })
      |> Milo.Accounts.get_or_create_user_from_google()

    user
  end
end
