defmodule Milo.AccountsTest do
  use Milo.DataCase

  describe "users" do
    import Milo.AccountsFixtures

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Milo.Accounts.get_user!(user.id) == user
    end
  end
end
