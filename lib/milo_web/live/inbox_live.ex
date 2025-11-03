defmodule MiloWeb.InboxLive do
  use MiloWeb, :live_view
  alias Milo.Content
  alias Milo.Accounts
  alias MiloWeb.Endpoint

  @impl true
  def mount(_params, %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    categories = Content.list_user_categories(user.id)
    category_names = Enum.map(categories, & &1.category.name)

    if connected?(socket), do: Endpoint.subscribe("inbox:lobby")

    {:ok,
     assign(socket,
       user: user,
       categories: category_names,
       emails: %{},
       active: List.first(category_names)
     )}
  end

  # Recebe novos e-mails broadcastados pelo SyncWorker
  @impl true
  def handle_info(%{event: "new_email", payload: %{category: cat, body: body, id: id}}, socket) do
    updated_emails =
      Map.update(socket.assigns.emails, cat, [%{id: id, body: body}], fn list ->
        [%{id: id, body: body} | list]
      end)

    {:noreply, assign(socket, emails: updated_emails)}
  end

  # Alternar entre as tabs de categorias
  @impl true
  def handle_event("switch_tab", %{"cat" => cat}, socket) do
    {:noreply, assign(socket, active: cat)}
  end
end
