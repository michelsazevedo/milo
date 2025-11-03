defmodule Milo.AI.CategorizerTest do
  use ExUnit.Case, async: true

  alias Milo.AI.Categorizer

  # Define a mock module for OpenAI
  defmodule OpenAIMock do
    def chat_completion(opts) do
      # Store the options in the process dictionary so tests can verify them
      Process.put(:last_openai_opts, opts)
      Process.get(:openai_response, {:ok, default_response()})
    end

    defp default_response do
      %{
        "choices" => [
          %{
            "message" => %{
              "content" => "Work"
            }
          }
        ]
      }
    end

    def get_last_opts, do: Process.get(:last_openai_opts)
    def set_response(response), do: Process.put(:openai_response, response)
    def reset, do: Process.delete(:openai_response)
  end

  setup do
    # Replace OpenAI module with mock during tests
    Application.put_env(:milo, :openai_module, OpenAIMock)
    OpenAIMock.reset()
    on_exit(fn ->
      Application.delete_env(:milo, :openai_module)
      OpenAIMock.reset()
    end)
    :ok
  end

  describe "categorize_email/2" do
    test "returns the category from OpenAI response" do
      email_body = "This is a work-related email about a project deadline."
      categories = ["Work", "Personal", "Finance", "Travel"]

      OpenAIMock.set_response({
        :ok,
        %{
          "choices" => [
            %{
              "message" => %{
                "content" => "Work"
              }
            }
          ]
        }
      })

      result = Categorizer.categorize_email(email_body, categories)

      # Verify the options passed to OpenAI
      opts = OpenAIMock.get_last_opts()
      assert opts[:model] == "gpt-4o-mini"
      assert length(opts[:messages]) == 1
      message = hd(opts[:messages])
      assert message[:role] == "user"
      assert String.contains?(message[:content], "Work, Personal, Finance, Travel")
      assert String.contains?(message[:content], email_body)

      assert result == "Work"
    end

    test "handles single category list" do
      email_body = "A simple email message."
      categories = ["Personal"]

      OpenAIMock.set_response({
        :ok,
        %{
          "choices" => [
            %{
              "message" => %{
                "content" => "Personal"
              }
            }
          ]
        }
      })

      result = Categorizer.categorize_email(email_body, categories)

      opts = OpenAIMock.get_last_opts()
      message = hd(opts[:messages])
      assert String.contains?(message[:content], "Personal")
      assert String.contains?(message[:content], email_body)

      assert result == "Personal"
    end

    test "trims whitespace from OpenAI response" do
      email_body = "Email content here"
      categories = ["Work", "Personal"]

      OpenAIMock.set_response({
        :ok,
        %{
          "choices" => [
            %{
              "message" => %{
                "content" => "  Work  \n"
              }
            }
          ]
        }
      })

      result = Categorizer.categorize_email(email_body, categories)

      assert result == "Work"
    end

    test "handles empty categories list" do
      email_body = "Email content"
      categories = []

      OpenAIMock.set_response({
        :ok,
        %{
          "choices" => [
            %{
              "message" => %{
                "content" => "Uncategorized"
              }
            }
          ]
        }
      })

      result = Categorizer.categorize_email(email_body, categories)

      opts = OpenAIMock.get_last_opts()
      message = hd(opts[:messages])
      # Should still create a valid prompt even with empty categories
      assert String.contains?(message[:content], email_body)

      assert result == "Uncategorized"
    end

    test "handles multiple categories with special characters" do
      email_body = "Email with special chars: <test@example.com>"
      categories = ["Work", "Personal & Family", "Finance/Banking"]

      OpenAIMock.set_response({
        :ok,
        %{
          "choices" => [
            %{
              "message" => %{
                "content" => "Personal & Family"
              }
            }
          ]
        }
      })

      result = Categorizer.categorize_email(email_body, categories)

      opts = OpenAIMock.get_last_opts()
      message = hd(opts[:messages])
      assert String.contains?(message[:content], "Work, Personal & Family, Finance/Banking")

      assert result == "Personal & Family"
    end

    test "handles long email body" do
      long_body = String.duplicate("This is a very long email body. ", 100)
      categories = ["Work", "Personal"]

      OpenAIMock.set_response({
        :ok,
        %{
          "choices" => [
            %{
              "message" => %{
                "content" => "Work"
              }
            }
          ]
        }
      })

      result = Categorizer.categorize_email(long_body, categories)

      opts = OpenAIMock.get_last_opts()
      message = hd(opts[:messages])
      # Ensure the full email body is included in the prompt
      assert String.contains?(message[:content], long_body)

      assert result == "Work"
    end
  end
end
