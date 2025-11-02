# test/milo_web/controllers/auth_controller_test.exs
defmodule MiloWeb.AuthControllerTest do
  use MiloWeb.ConnCase, async: true
  import Mox

  alias Milo.Repo

  setup :verify_on_exit!

  setup do
    google_config = [
      client_id: "fake-client-id",
      client_secret: "fake-client-secret",
      redirect_uri: "http://localhost:4000/auth/google/callback",
      strategy: Milo.GoogleStrategyMock
    ]

    Application.put_env(:assent, :providers, google: google_config)

    {:ok, google_config: google_config}
  end

  describe "request/2 with provider=google" do
    test "redirects to Google's authorize URL and stores session_params", %{} do
      expect(Milo.GoogleStrategyMock, :authorize_url, fn _config ->
        {:ok, %{url: "http://localhost:4000/oauth/authorize", session_params: %{"state" => "xyz"}}}
      end)

      conn =
        build_conn()
        |> get(~p"/auth/google")

      assert redirected_to(conn) =~ "/oauth/authorize"
      assert get_session(conn, :google_session_params) == %{"state" => "xyz"}
    end

    test "shows flash error when Google.authorize_url fails", %{} do
      expect(Milo.GoogleStrategyMock, :authorize_url, fn _config ->
        {:error, :network_error}
      end)

      conn =
        build_conn()
        |> get(~p"/auth/google")

      assert redirected_to(conn) == ~p"/signup"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Error connecting to Google."
    end
  end

  describe "callback/2 with provider=google – happy path" do
    setup %{google_config: _config} do
      session_params = %{"state" => "random-state-123"}

      expect(Milo.GoogleStrategyMock, :authorize_url, fn _cfg ->
        {:ok, %{url: "http://localhost:4000/oauth/authorize", session_params: session_params}}
      end)

      conn =
        build_conn()
        |> get(~p"/auth/google")

      {:ok, conn: conn, session_params: session_params}
    end

    test "creates a new user, logs them in and redirects to onboarding", ctx do
      expect(Milo.GoogleStrategyMock, :callback, fn _cfg, _params ->
        {:ok,
         %{
           user: %{"email" => "new.user@example.com", "name" => "New User"},
           token: %{"access_token" => "acc-123"}
         }}
      end)

      callback_conn =
        ctx.conn
        |> recycle()
        |> get(~p"/auth/google/callback?code=authcode123&state=#{ctx.session_params["state"]}")

      assert redirected_to(callback_conn) == ~p"/onboarding"
      user_id = get_session(callback_conn, :user_id)
      assert user_id

      user = Repo.get!(Milo.Accounts.User, user_id)
      assert user.email == "new.user@example.com"
      assert user.name == "New User"
      assert user.google_token == "acc-123"
    end
  end

  describe "callback/2 – existing user" do
    setup %{google_config: _config} do
      {:ok, user} =
        %Milo.Accounts.User{}
        |> Milo.Accounts.User.changeset(%{
          email: "existing@example.com",
          name: "Old Name",
          google_token: "old-token"
        })
        |> Repo.insert()

      session_params = %{"state" => "state-xyz"}

      expect(Milo.GoogleStrategyMock, :authorize_url, fn _cfg ->
        {:ok, %{url: "http://localhost:4000/oauth/authorize", session_params: session_params}}
      end)

      conn =
        build_conn()
        |> get(~p"/auth/google")

      {:ok,
       conn: conn,
       user: user,
       session_params: session_params}
    end

    test "updates existing user's token & name", ctx do
      expect(Milo.GoogleStrategyMock, :callback, fn _cfg, _params ->
        {:ok,
         %{
           user: %{"email" => ctx.user.email, "name" => "Updated Name"},
           token: %{"access_token" => "new-access"}
         }}
      end)

      callback_conn =
        ctx.conn
        |> recycle()
        |> get(~p"/auth/google/callback?code=authcode&state=#{ctx.session_params["state"]}")

      assert redirected_to(callback_conn) == ~p"/onboarding"
      assert get_session(callback_conn, :user_id) == ctx.user.id

      updated = Repo.get!(Milo.Accounts.User, ctx.user.id)
      assert updated.name == "Updated Name"
      assert updated.google_token == "new-access"
    end
  end

  describe "callback/2 error handling" do
    setup %{google_config: _config} do
      session_params = %{"state" => "valid-state"}

      expect(Milo.GoogleStrategyMock, :authorize_url, fn _cfg ->
        {:ok, %{url: "http://localhost:4000/oauth/authorize", session_params: session_params}}
      end)

      conn =
        build_conn()
        |> get(~p"/auth/google")

      {:ok, conn: conn, session_params: session_params}
    end

    test "missing session_params → flash error", %{} do
      callback_conn =
        build_conn()
        |> get(~p"/auth/google/callback?code=any&state=valid-state")

      assert redirected_to(callback_conn) == ~p"/signup"
      assert Phoenix.Flash.get(callback_conn.assigns.flash, :error) == "Invalid OAuth session."
    end

    test "Google.callback returns error → flash error", ctx do
      expect(Milo.GoogleStrategyMock, :callback, fn _cfg, _params ->
        {:error, :invalid_code}
      end)

      callback_conn =
        ctx.conn
        |> recycle()
        |> get(~p"/auth/google/callback?code=bad&state=#{ctx.session_params["state"]}")

      assert redirected_to(callback_conn) == ~p"/signup"
      assert Phoenix.Flash.get(callback_conn.assigns.flash, :error) == "Error during Google authentication."
    end

    test "Accounts.get_or_create_user_from_google fails → flash error", ctx do
      expect(Milo.GoogleStrategyMock, :callback, fn _cfg, _params ->
        {:ok,
         %{
           user: %{"email" => "", "name" => ""},  # Invalid: empty email will fail validation
           token: %{"access_token" => "tok"}
         }}
      end)

      callback_conn =
        ctx.conn
        |> recycle()
        |> get(~p"/auth/google/callback?code=any&state=#{ctx.session_params["state"]}")

      assert redirected_to(callback_conn) == ~p"/signup"
      assert Phoenix.Flash.get(callback_conn.assigns.flash, :error) == "Error saving user."
    end
  end
end
