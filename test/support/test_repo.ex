defmodule Pager.TestRepo do
  use Ecto.Repo,
    otp_app: :pager,
    adapter: Ecto.Adapters.Postgres

  def init(_context, config) do
    test_config = [
      pool: Ecto.Adapters.SQL.Sandbox,
      username: "postgres",
      password: "postgres",
      database: "pager_test",
      hostname: System.get_env("DB_HOST", "localhost"),
      port: System.get_env("DB_PORT", "5432")
    ]

    {:ok, Keyword.merge(config, test_config)}
  end

  use Pager, queries: Pager.TestQueries
end
