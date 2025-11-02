defmodule MiloWeb.OnboardingLive do
  use MiloWeb, :live_view
  alias Milo.Accounts

  def mount(_params, session, socket) do
    user =
      case session["user_id"] do
        nil -> nil
        id -> Accounts.get_user!(id)
      end

    {:ok, assign(socket, :user, user)}
  end

  def render(assigns) do
    ~H"""
    <div class="p-8 text-center">
      <h2 class="text-3xl font-bold mb-4">Welcome, <%= @user && @user.name %>!</h2>
      <p class="text-gray-600">Let’s start setting up your account...</p>
    </div>
    """
  end
end
