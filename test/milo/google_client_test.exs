defmodule Milo.GoogleClientTest do
  use ExUnit.Case, async: true

  alias Milo.GoogleClient

  setup do
    bypass = Bypass.open()
    Application.put_env(:milo, :gmail_base_url, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      Application.delete_env(:milo, :gmail_base_url)
    end)

    {:ok, bypass: bypass}
  end

  describe "list_new_messages/2" do
    test "returns list of unique message IDs from Gmail history API", %{bypass: bypass} do
      history_response = %{
        "history" => [
          %{
            "messages" => [
              %{"id" => "msg1"},
              %{"id" => "msg2"}
            ]
          },
          %{
            "messages" => [
              %{"id" => "msg2"}, # duplicate
              %{"id" => "msg3"}
            ]
          }
        ]
      }

      Bypass.expect_once(bypass, "GET", "/gmail/v1/users/me/history", fn conn ->
        assert conn.query_params["startHistoryId"] == "12345"
        assert {"authorization", "Bearer test-token"} in conn.req_headers

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(history_response))
      end)

      messages = GoogleClient.list_new_messages("test-token", "12345")

      assert length(messages) == 3
      assert Enum.any?(messages, &(&1["id"] == "msg1"))
      assert Enum.any?(messages, &(&1["id"] == "msg2"))
      assert Enum.any?(messages, &(&1["id"] == "msg3"))
    end

    test "handles empty history gracefully", %{bypass: bypass} do
      history_response = %{"history" => []}

      Bypass.expect_once(bypass, "GET", "/gmail/v1/users/me/history", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(history_response))
      end)

      messages = GoogleClient.list_new_messages("test-token", "12345")

      assert messages == []
    end

    test "handles history entries without messages field", %{bypass: bypass} do
      history_response = %{
        "history" => [
          %{"messages" => [%{"id" => "msg1"}]},
          %{} # no messages field
        ]
      }

      Bypass.expect_once(bypass, "GET", "/gmail/v1/users/me/history", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(history_response))
      end)

      messages = GoogleClient.list_new_messages("test-token", "12345")

      assert length(messages) == 1
      assert Enum.any?(messages, &(&1["id"] == "msg1"))
    end
  end

  describe "get_message_body/2" do
    test "returns decoded message body from text/plain part", %{bypass: bypass} do
      message_id = "msg123"
      encoded_body = Base.url_encode64("Hello, this is a test email body", padding: false)

      message_response = %{
        "payload" => %{
          "parts" => [
            %{
              "mimeType" => "text/html",
              "body" => %{"data" => Base.url_encode64("<p>HTML version</p>", padding: false)}
            },
            %{
              "mimeType" => "text/plain",
              "body" => %{"data" => encoded_body}
            }
          ]
        }
      }

      Bypass.expect_once(bypass, "GET", "/gmail/v1/users/me/messages/#{message_id}", fn conn ->
        assert conn.query_params["format"] == "full"
        assert {"authorization", "Bearer test-token"} in conn.req_headers

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(message_response))
      end)

      body = GoogleClient.get_message_body("test-token", message_id)

      assert body == "Hello, this is a test email body"
    end

    test "handles message without text/plain part", %{bypass: bypass} do
      message_id = "msg456"

      message_response = %{
        "payload" => %{
          "parts" => [
            %{
              "mimeType" => "text/html",
              "body" => %{"data" => Base.url_encode64("<p>Only HTML</p>", padding: false)}
            }
          ]
        }
      }

      Bypass.expect_once(bypass, "GET", "/gmail/v1/users/me/messages/#{message_id}", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(message_response))
      end)

      # This will raise an error since there's no text/plain part (Enum.find returns nil)
      assert_raise FunctionClauseError, fn ->
        GoogleClient.get_message_body("test-token", message_id)
      end
    end
  end

  describe "archive_message/2" do
    test "sends archive request to Gmail API", %{bypass: bypass} do
      message_id = "msg789"

      Bypass.expect_once(bypass, "POST", "/gmail/v1/users/me/messages/#{message_id}/modify", fn conn ->
        assert {"authorization", "Bearer test-token"} in conn.req_headers
        assert {"content-type", "application/json"} in conn.req_headers

        {:ok, body, _} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)

        assert request_data["removeLabelIds"] == ["INBOX"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"id" => message_id}))
      end)

      result = GoogleClient.archive_message("test-token", message_id)

      assert {:ok, %{status: 200}} = result
    end

    test "handles API errors", %{bypass: bypass} do
      message_id = "msg999"

      Bypass.expect_once(bypass, "POST", "/gmail/v1/users/me/messages/#{message_id}/modify", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      result = GoogleClient.archive_message("test-token", message_id)

      assert {:ok, %{status: 401}} = result
    end
  end
end
