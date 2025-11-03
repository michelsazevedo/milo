ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Milo.Repo, :manual)

Mox.defmock(Milo.GoogleStrategyMock, for: Assent.Strategy)

# Start Oban globally for all tests
config = Application.get_env(:milo, Oban, [])
oban_config =
  config
  |> Keyword.put_new(:name, Oban)
  |> Keyword.put_new(:repo, Milo.Repo)
  |> Keyword.put_new(:engine, Oban.Engines.Basic)
  |> Keyword.put_new(:queues, false)
  |> Keyword.put_new(:plugins, false)

Application.put_env(:milo, Oban, oban_config, persistent: false)

case Process.whereis(Oban) do
  nil ->
    case Oban.start_link(oban_config) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      other -> IO.puts("Warning: Oban failed to start globally: #{inspect(other)}")
    end
  _pid -> :ok
end
