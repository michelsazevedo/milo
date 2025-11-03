defmodule MiloWeb.GmailWebhookControllerTest do
  use MiloWeb.ConnCase, async: true

  alias Milo.Accounts

  describe "receive" do
    test "successfully processes valid webhook and returns 200", %{conn: conn} do
      # Create a test user
      {:ok, _user} =
        Accounts.get_or_create_user_from_google(%{
          "email" => "test@example.com",
          "name" => "Test User",
          "google_token" => "test-token"
        })

      # Create valid webhook payload
      payload = %{
        "emailAddress" => "test@example.com",
        "historyId" => "12345"
      }

      message_data = %{
        "data" => Base.encode64(Jason.encode!(payload))
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhook/gmail", %{"message" => message_data})

      assert response(conn, 200) == "ok"
    end

    test "returns 400 when message is missing", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhook/gmail", %{})

      assert response(conn, 400) == "invalid request"
    end

    test "returns 400 when message data is invalid base64", %{conn: conn} do
      message_data = %{
        "data" => "invalid-base64!!!"
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhook/gmail", %{"message" => message_data})

      assert response(conn, 400) == "error"
    end

    test "returns 400 when payload is invalid JSON", %{conn: conn} do
      message_data = %{
        "data" => Base.encode64("invalid json {")
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhook/gmail", %{"message" => message_data})

      assert response(conn, 400) == "error"
    end

    test "returns 400 when payload is missing emailAddress", %{conn: conn} do
      # Create a test user
      {:ok, _user} =
        Accounts.get_or_create_user_from_google(%{
          "email" => "test2@example.com",
          "name" => "Test User 2",
          "google_token" => "test-token-2"
        })

      payload = %{
        "historyId" => "12345"
      }

      message_data = %{
        "data" => Base.encode64(Jason.encode!(payload))
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhook/gmail", %{"message" => message_data})

      assert response(conn, 400) == "error"
    end

    test "returns 400 when payload is missing historyId", %{conn: conn} do
      # Create a test user
      {:ok, _user} =
        Accounts.get_or_create_user_from_google(%{
          "email" => "test3@example.com",
          "name" => "Test User 3",
          "google_token" => "test-token-3"
        })

      payload = %{
        "emailAddress" => "test3@example.com"
      }

      message_data = %{
        "data" => Base.encode64(Jason.encode!(payload))
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhook/gmail", %{"message" => message_data})

      assert response(conn, 400) == "error"
    end

    test "returns 400 when user is not found", %{conn: conn} do
      payload = %{
        "emailAddress" => "nonexistent@example.com",
        "historyId" => "12345"
      }

      message_data = %{
        "data" => Base.encode64(Jason.encode!(payload))
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhook/gmail", %{"message" => message_data})

      assert response(conn, 400) == "error"
    end

    test "returns 400 for invalid params structure", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/webhook/gmail", %{"something" => "else"})

      assert response(conn, 400) == "invalid request"
    end
  end
end
