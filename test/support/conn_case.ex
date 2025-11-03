defmodule MiloWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use MiloWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint MiloWeb.Endpoint

      use MiloWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import MiloWeb.ConnCase
    end
  end

  setup tags do
    Milo.DataCase.setup_sandbox(tags)

    # Ensure Oban is started for testing with the correct name and config
    config =
      Application.get_env(:milo, Oban, [])
      |> Keyword.put_new(:name, Oban)
      |> Keyword.put_new(:repo, Milo.Repo)

    # Ensure config is available
    Application.put_env(:milo, Oban, config, persistent: false)

    case Process.whereis(Oban) do
      nil ->
        case Oban.start_link(config) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
        end
      _pid ->
        :ok
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
