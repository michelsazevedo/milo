ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Milo.Repo, :manual)

Mox.defmock(Milo.GoogleStrategyMock, for: Assent.Strategy)
