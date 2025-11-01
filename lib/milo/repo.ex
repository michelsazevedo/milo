defmodule Milo.Repo do
  use Ecto.Repo,
    otp_app: :milo,
    adapter: Ecto.Adapters.Postgres
end
