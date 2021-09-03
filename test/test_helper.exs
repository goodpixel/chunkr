Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)

_ = Ecto.Adapters.Postgres.storage_down(Pager.Repo.config())
:ok = Ecto.Adapters.Postgres.storage_up(Pager.Repo.config())
{:ok, _} = Pager.Repo.start_link()
:ok = Ecto.Migrator.up(Pager.Repo, 0, Pager.Migration)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Pager.Repo, :manual)
