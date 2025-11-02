defmodule MiloWeb.OnboardingLive do
  use MiloWeb, :live_view
  alias Milo.Content
  alias Milo.Accounts

  def mount(_params, session, socket) do
    user = case session["user_id"] do
      nil -> nil
      id -> Accounts.get_user!(id)
    end

    if user do
      categories = Content.list_categories()
      existing_selected = Content.list_user_category_ids(user.id)

      {:ok,
       socket
       |> assign(
         user: user,
         categories: categories,
         selected: existing_selected,
         show_modal: false,
         error_message: nil
       )}
    else
      {:ok, socket |> put_flash(:error, "Please sign in") |> push_navigate(to: "/signup")}
    end
  end

  def handle_event("toggle_category", %{"id" => id}, socket) do
    selected =
      if id in socket.assigns.selected do
        List.delete(socket.assigns.selected, id)
      else
        [id | socket.assigns.selected]
      end

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_event("open_modal", _, socket), do: {:noreply, assign(socket, show_modal: true)}
  def handle_event("close_modal", _, socket), do: {:noreply, assign(socket, show_modal: false)}

  def handle_event("next", _, socket) do
    selected_ids = socket.assigns.selected

    if Enum.empty?(selected_ids) do
      {:noreply,
       socket
       |> put_flash(:error, "Please select at least one category to continue")
       |> assign(:error_message, "Please select at least one category")}
    else
      user = socket.assigns.user

      # Remove all existing associations
      existing_ids = Content.list_user_category_ids(user.id)
      for category_id <- existing_ids do
        Content.dissociate_user_category(user.id, category_id)
      end

      # Add new associations
      for category_id <- selected_ids do
        Content.associate_user_category(user.id, category_id)
      end

      {:noreply, push_navigate(socket, to: "/inbox")}
    end
  end

  def handle_info({:category_created, _category}, socket) do
    {:noreply,
     socket
     |> assign(:categories, Content.list_categories())
     |> assign(:show_modal, false)}
  end

  def handle_info(:close_modal, socket) do
    {:noreply, assign(socket, show_modal: false)}
  end
end
