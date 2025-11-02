defmodule MiloWeb.CategoryModalComponent do
  use MiloWeb, :live_component
  alias Milo.Content
  alias Milo.Content.Category

  def update(assigns, socket) do
    form = to_form(Category.changeset(%Category{}, %{}))
    {:ok, socket |> assign(assigns) |> assign(:form, form)}
  end

  def render(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
      phx-click="close_modal"
      phx-target={@myself}
      id="modal-backdrop"
    >
      <div
        class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4"
        phx-click="stop_propagation"
        phx-target={@myself}
      >
        <div class="p-6">
          <h2 class="text-lg font-semibold mb-4 text-gray-700">Add Custom Category</h2>

          <.form
            for={@form}
            id="category-form"
            phx-submit="save"
            phx-target={@myself}
          >
            <.input field={@form[:name]} label="Name" placeholder="Enter category name" />
            <.input field={@form[:description]} type="textarea" label="Description" placeholder="Describe this category" />

            <div class="flex justify-end gap-3 mt-4">
              <button
                type="button"
                phx-click="close_modal"
                phx-target={@myself}
                class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                phx-disable-with="Saving..."
                class="px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg"
              >
                Save
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("stop_propagation", _, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"category" => params}, socket) do
    case Content.create_category(params) do
      {:ok, category} ->
        send(self(), {:category_created, category})
        {:noreply, socket |> put_flash(:info, "Category created!") |> push_event("close_modal", %{})}

      {:error, changeset} ->
        form = to_form(changeset)
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("close_modal", _, socket) do
    send(self(), :close_modal)
    {:noreply, socket}
  end
end
