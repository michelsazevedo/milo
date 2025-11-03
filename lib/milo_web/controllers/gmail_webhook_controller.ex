defmodule MiloWeb.GmailWebhookController do
  use MiloWeb, :controller

  alias Milo.{Workers.SyncWorker, Accounts}
  require Logger

  def receive(conn, %{"message" => message}) do
    with {:ok, decoded_binary} <- decode_message(message),
         {:ok, payload} <- Jason.decode(decoded_binary),
         %{"emailAddress" => email, "historyId" => history_id} <- payload,
         {:ok, user} <- Accounts.get_user_by_email(email) do
      %{ "user_id" => user.id, "history_id" => history_id }
      |> SyncWorker.new()
      |> Oban.insert()
      |> case do
        {:ok, _job} -> :ok
        {:error, _reason} -> :error
      end

      send_resp(conn, 200, "ok")
    else
      _error ->
        send_resp(conn, 400, "error")
    end
  end

  def receive(conn, _params), do: send_resp(conn, 400, "invalid request")

  defp decode_message(%{"data" => data}) do
    case Base.decode64(data, padding: false) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:error, :invalid_base64}
    end
  end
end
