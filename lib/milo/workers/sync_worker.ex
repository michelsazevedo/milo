defmodule Milo.Workers.SyncWorker do
  use Oban.Worker, queue: :gmail
  alias Milo.{GoogleClient, Accounts, Content}
  alias MiloWeb.Endpoint
  alias Milo.AI.Categorizer

  @google_client_module Application.compile_env(:milo, :google_client_module, GoogleClient)
  @categorizer_module Application.compile_env(:milo, :categorizer_module, Categorizer)
  @endpoint_module Application.compile_env(:milo, :endpoint_module, Endpoint)

  @impl true
  def perform(%Oban.Job{args: %{"history_id" => history_id, "user_id" => user_id}}) do
    user = Accounts.get_user!(user_id)
    access_token = user.google_token

    messages = google_client_module().list_new_messages(access_token, history_id)

    Enum.each(messages, fn message ->
      body = google_client_module().get_message_body(access_token, message["id"])
      user_categories = Content.list_user_categories(user.id)
      category_names = Enum.map(user_categories, & &1.category.name)
      category = categorizer_module().categorize_email(body, category_names)

      google_client_module().archive_message(access_token, message["id"])

      # Envia para LiveView
      endpoint_module().broadcast("inbox:lobby", "new_email", %{
        id: message["id"],
        category: category,
        body: body
      })
    end)

    :ok
  end

  defp google_client_module do
    Application.get_env(:milo, :google_client_module, @google_client_module)
  end

  defp categorizer_module do
    Application.get_env(:milo, :categorizer_module, @categorizer_module)
  end

  defp endpoint_module do
    Application.get_env(:milo, :endpoint_module, @endpoint_module)
  end
end
