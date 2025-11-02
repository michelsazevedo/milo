defmodule MiloWeb.AuthController do
  use MiloWeb, :controller
  alias Milo.Accounts

  def request(conn, %{"provider" => "google"}) do
    config = Application.fetch_env!(:assent, :providers)[:google]
    strategy = config[:strategy] || Assent.Strategy.Google

    case strategy.authorize_url(config) do
      {:ok, %{url: url, session_params: session_params}} ->
        conn
        |> configure_session(renew: false)
        |> put_session(:google_session_params, session_params)
        |> redirect(external: url)

      {:error, _} ->
        conn
        |> put_flash(:error, "Error connecting to Google.")
        |> redirect(to: ~p"/signup")
    end
  end

  def callback(conn, %{"provider" => "google"} = params) do
    config = Application.fetch_env!(:assent, :providers)[:google]
    strategy = config[:strategy] || Assent.Strategy.Google
    session_params = get_session(conn, :google_session_params)

    if session_params do
      case strategy.callback(Keyword.put(config, :session_params, session_params), params) do
        {:ok, %{user: userinfo, token: token}} ->
          attrs = %{
            "email" => userinfo["email"],
            "name" => userinfo["name"] || userinfo["email"],
            "google_token" => token["access_token"],
            "refresh_token" => Map.get(token, "refresh_token")
          }

          case Accounts.get_or_create_user_from_google(attrs) do
            {:ok, user} ->
              conn
              |> configure_session(renew: true)
              |> put_session(:user_id, user.id)
              |> redirect(to: ~p"/onboarding")

            {:error, _changeset} ->
              conn
              |> put_flash(:error, "Error saving user.")
              |> redirect(to: ~p"/signup")
          end
        {:error, _reason} ->
          conn
          |> put_flash(:error, "Error during Google authentication.")
          |> redirect(to: ~p"/signup")
      end
    else
      conn
      |> put_flash(:error, "Invalid OAuth session.")
      |> redirect(to: ~p"/signup")
    end
  end
end
