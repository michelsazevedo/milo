defmodule Milo.Workers.SyncWorkerTest do
  use Milo.DataCase, async: true

  alias Milo.Workers.SyncWorker
  alias Milo.{Accounts, Content}

  # Mock modules
  defmodule GoogleClientMock do
    def list_new_messages(_token, _history_id) do
      Process.get(:mock_messages, [])
    end

    def get_message_body(_token, message_id) do
      Process.get({:mock_body, message_id}, "Default email body")
    end

    def archive_message(_token, message_id) do
      # Store archived message IDs
      archived = Process.get(:archived_messages, [])
      Process.put(:archived_messages, [message_id | archived])
      {:ok, %{status: 200}}
    end

    def set_messages(messages), do: Process.put(:mock_messages, messages)
    def set_body(message_id, body), do: Process.put({:mock_body, message_id}, body)
    def get_archived, do: Process.get(:archived_messages, [])
    def reset do
      Process.delete(:mock_messages)
      Process.delete(:archived_messages)
      Enum.each(Process.get() |> Keyword.keys(), fn key ->
        if is_tuple(key) and elem(key, 0) == :mock_body do
          Process.delete(key)
        end
      end)
    end
  end

  defmodule CategorizerMock do
    def categorize_email(body, _categories) do
      Process.get({:mock_category, body}, "Work")
    end

    def set_category(body, category), do: Process.put({:mock_category, body}, category)
    def reset, do: :ok
  end

  defmodule EndpointMock do
    def broadcast(_topic, _event, payload) do
      send(self(), {:broadcast, payload})
      :ok
    end
  end

  setup do
    # Create a test user
    {:ok, user} =
      Accounts.get_or_create_user_from_google(%{
        "email" => "test@example.com",
        "name" => "Test User",
        "google_token" => "test-google-token"
      })

    # Get or create test categories
    cat1 = get_or_create_category("Work", "Work emails", true)
    cat2 = get_or_create_category("Personal", "Personal emails", true)

    # Associate user with categories
    Content.associate_user_category(user.id, cat1.id)
    Content.associate_user_category(user.id, cat2.id)

    # Setup mocks
    GoogleClientMock.reset()
    CategorizerMock.reset()

    # Store original modules and replace with mocks
    original_modules = %{
      google_client: Application.get_env(:milo, :google_client_module),
      categorizer: Application.get_env(:milo, :categorizer_module),
      endpoint: Application.get_env(:milo, :endpoint_module)
    }

    Application.put_env(:milo, :google_client_module, GoogleClientMock, persistent: false)
    Application.put_env(:milo, :categorizer_module, CategorizerMock, persistent: false)
    Application.put_env(:milo, :endpoint_module, EndpointMock, persistent: false)

    on_exit(fn ->
      GoogleClientMock.reset()
      CategorizerMock.reset()

      # Restore original modules
      case original_modules.google_client do
        nil -> Application.delete_env(:milo, :google_client_module)
        val -> Application.put_env(:milo, :google_client_module, val, persistent: false)
      end

      case original_modules.categorizer do
        nil -> Application.delete_env(:milo, :categorizer_module)
        val -> Application.put_env(:milo, :categorizer_module, val, persistent: false)
      end

      case original_modules.endpoint do
        nil -> Application.delete_env(:milo, :endpoint_module)
        val -> Application.put_env(:milo, :endpoint_module, val, persistent: false)
      end
    end)

    {:ok, user: user, categories: [cat1, cat2]}
  end

  describe "perform/1" do
    test "processes new messages and broadcasts them", %{user: user} do
      history_id = "12345"
      messages = [
        %{"id" => "msg1"},
        %{"id" => "msg2"}
      ]

      # Setup mocks
      GoogleClientMock.set_messages(messages)
      GoogleClientMock.set_body("msg1", "This is a work email about a project.")
      GoogleClientMock.set_body("msg2", "This is a personal email about dinner.")
      CategorizerMock.set_category("This is a work email about a project.", "Work")
      CategorizerMock.set_category("This is a personal email about dinner.", "Personal")

      job = %Oban.Job{
        id: 1,
        args: %{"history_id" => history_id, "user_id" => user.id},
        worker: SyncWorker,
        queue: :gmail,
        state: :available
      }

      result = SyncWorker.perform(job)

      assert result == :ok

      # Verify broadcasts were sent
      assert_received {:broadcast, %{id: "msg1", category: "Work", body: "This is a work email about a project."}}
      assert_received {:broadcast, %{id: "msg2", category: "Personal", body: "This is a personal email about dinner."}}
    end

    test "handles empty message list", %{user: user} do
      history_id = "12345"

      GoogleClientMock.set_messages([])

      job = %Oban.Job{
        id: 1,
        args: %{"history_id" => history_id, "user_id" => user.id},
        worker: SyncWorker,
        queue: :gmail,
        state: :available
      }

      result = SyncWorker.perform(job)

      assert result == :ok

      # Verify no broadcasts were sent
      refute_received {:broadcast, _}
    end

    test "archives messages after processing", %{user: user} do
      history_id = "12345"
      messages = [%{"id" => "msg1"}]

      GoogleClientMock.set_messages(messages)
      GoogleClientMock.set_body("msg1", "Email body")
      CategorizerMock.set_category("Email body", "Work")

      job = %Oban.Job{
        id: 1,
        args: %{"history_id" => history_id, "user_id" => user.id},
        worker: SyncWorker,
        queue: :gmail,
        state: :available
      }

      SyncWorker.perform(job)

      # Verify message was archived
      archived = GoogleClientMock.get_archived()
      assert "msg1" in archived
    end

    test "uses user categories for categorization", %{user: user, categories: [_cat1, _cat2]} do
      history_id = "12345"
      messages = [%{"id" => "msg1"}]

      GoogleClientMock.set_messages(messages)
      GoogleClientMock.set_body("msg1", "Email about work project")
      CategorizerMock.set_category("Email about work project", "Work")

      job = %Oban.Job{
        id: 1,
        args: %{"history_id" => history_id, "user_id" => user.id},
        worker: SyncWorker,
        queue: :gmail,
        state: :available
      }

      SyncWorker.perform(job)

      # Verify categorizer was called (indirectly by checking the broadcast)
      assert_received {:broadcast, %{category: "Work"}}

      # Verify categories were passed (check that user categories exist)
      user_categories = Content.list_user_categories(user.id)
      assert length(user_categories) == 2
      assert Enum.any?(user_categories, &(&1.category.name == "Work"))
      assert Enum.any?(user_categories, &(&1.category.name == "Personal"))
    end

    test "processes multiple messages in sequence", %{user: user} do
      history_id = "12345"
      messages = [
        %{"id" => "msg1"},
        %{"id" => "msg2"},
        %{"id" => "msg3"}
      ]

      GoogleClientMock.set_messages(messages)
      GoogleClientMock.set_body("msg1", "Body 1")
      GoogleClientMock.set_body("msg2", "Body 2")
      GoogleClientMock.set_body("msg3", "Body 3")
      CategorizerMock.set_category("Body 1", "Work")
      CategorizerMock.set_category("Body 2", "Personal")
      CategorizerMock.set_category("Body 3", "Work")

      job = %Oban.Job{
        id: 1,
        args: %{"history_id" => history_id, "user_id" => user.id},
        worker: SyncWorker,
        queue: :gmail,
        state: :available
      }

      result = SyncWorker.perform(job)

      assert result == :ok

      # Verify all messages were processed
      archived = GoogleClientMock.get_archived()
      assert "msg1" in archived
      assert "msg2" in archived
      assert "msg3" in archived

      # Verify all broadcasts were sent
      assert_received {:broadcast, %{id: "msg1"}}
      assert_received {:broadcast, %{id: "msg2"}}
      assert_received {:broadcast, %{id: "msg3"}}
    end
  end

  defp get_or_create_category(name, description, is_default) do
    case Content.get_category_by_name(name) do
      nil ->
        {:ok, category} = Content.create_category(%{
          "name" => name,
          "description" => description,
          "is_default" => is_default
        })
        category

      category ->
        category
    end
  end
end
