Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto)

_ = Ecto.Adapters.Postgres.storage_down(Chunkr.TestRepo.config())
:ok = Ecto.Adapters.Postgres.storage_up(Chunkr.TestRepo.config())
{:ok, _} = Chunkr.TestRepo.start_link()
:ok = Ecto.Migrator.up(Chunkr.TestRepo, 0, Chunkr.Migration)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Chunkr.TestRepo, :manual)
