defmodule MiloWeb.InboxLive do
  use MiloWeb, :live_view
  alias Milo.Accounts

  def mount(_params, session, socket) do
    user = case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end

    if user do
      {:ok, assign(socket, :user, user)}
    else
      {:ok, socket |> put_flash(:error, "Please sign in") |> push_navigate(to: "/signup")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="p-6">
      <h1 class="text-2xl font-bold">Inbox</h1>
      <p class="mt-2 text-gray-600">This is your inbox — here you'll later see emails organized by categories.</p>
    </div>
    """
  end
end
