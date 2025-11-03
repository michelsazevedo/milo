defmodule Milo.GoogleClient do
  @gmail_base_url_default "https://gmail.googleapis.com"

  defp gmail_base_url do
    Application.get_env(:milo, :gmail_base_url, @gmail_base_url_default)
  end

  defp gmail_base_path do
    "#{gmail_base_url()}/gmail/v1/users/me"
  end

  def list_new_messages(access_token, history_id) do
    headers = [{"Authorization", "Bearer #{access_token}"}]
    {:ok, %{body: body}} = Req.get("#{gmail_base_path()}/history?startHistoryId=#{history_id}", headers: headers)

    body["history"]
    |> Enum.flat_map(&(&1["messages"] || []))
    |> Enum.uniq_by(& &1["id"])
  end

  def get_message_body(access_token, id) do
    headers = [{"Authorization", "Bearer #{access_token}"}]
    {:ok, %{body: body}} = Req.get("#{gmail_base_path()}/messages/#{id}?format=full", headers: headers)

    body["payload"]["parts"]
    |> Enum.find(&(&1["mimeType"] == "text/plain"))
    |> then(&Base.url_decode64!(&1["body"]["data"], padding: false))
  end

  def archive_message(access_token, id) do
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    Req.post("#{gmail_base_path()}/messages/#{id}/modify",
      headers: headers,
      body: Jason.encode!(%{removeLabelIds: ["INBOX"]})
    )
  end
end
