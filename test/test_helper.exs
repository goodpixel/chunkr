Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)

_ = Ecto.Adapters.Postgres.storage_down(Pager.TestRepo.config())
:ok = Ecto.Adapters.Postgres.storage_up(Pager.TestRepo.config())
{:ok, _} = Pager.TestRepo.start_link()
:ok = Ecto.Migrator.up(Pager.TestRepo, 0, Pager.Migration)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Pager.TestRepo, :manual)
