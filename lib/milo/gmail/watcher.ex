defmodule Milo.Gmail.Watcher do
  @endpoint "https://gmail.googleapis.com/gmail/v1/users/me/watch"

  def register_watch(user) do
    headers = [
      {"Authorization", "Bearer #{user.google_token}"},
      {"Content-Type", "application/json"}
    ]

    project_id = System.get_env("GOOGLE_PROJECT_ID")

    body = Jason.encode!(%{
      topicName: "projects/#{project_id}/topics/gmail-webhook",
      labelIds: ["INBOX"]
    })

    Req.post!(@endpoint, headers: headers, body: body)
  end
end
