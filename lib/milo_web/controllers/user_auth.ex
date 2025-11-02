defmodule MiloWeb.UserAuth do
  @behaviour Plug
  import Plug.Conn
  import Phoenix.Controller

  @impl Plug
  def init(function) when is_atom(function), do: function

  @impl Plug
  def call(conn, :fetch_current_user) do
    fetch_current_user(conn, [])
  end

  def call(conn, :require_authenticated_user) do
    require_authenticated_user(conn, [])
  end

  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)

    user =
      if user_id do
        try do
          Milo.Accounts.get_user!(user_id)
        rescue
          _ -> nil
        end
      else
        nil
      end

    assign(conn, :current_user, user)
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> redirect(to: "/")
      |> halt()
    end
  end
end
