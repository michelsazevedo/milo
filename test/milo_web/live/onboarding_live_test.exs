# test/milo_web/live/onboarding_live_test.exs
defmodule MiloWeb.OnboardingLiveTest do
  use MiloWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Milo.Accounts

  test "shows user name when logged in", %{conn: conn} do
    {:ok, user} = Accounts.get_or_create_user_from_google(%{
      "email" => "jane@example.com",
      "name" => "Jane Doe",
      "google_token" => "tok"
    })

    conn =
      conn
      |> init_test_session(user_id: user.id)
      |> get(~p"/onboarding")

    {:ok, _view, html} = live(conn)
    assert html =~ "Welcome, Jane Doe!"
  end

  test "shows nothing when not logged in", %{conn: conn} do
    conn = get(conn, ~p"/onboarding")
    {:ok, _view, html} = live(conn)
    assert html =~ "Welcome, !"
  end
end
