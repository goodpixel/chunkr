defmodule Chunkr.TestRepo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :chunkr,
    adapter: Ecto.Adapters.Postgres

  def init(_context, config) do
    test_config = [
      pool: Ecto.Adapters.SQL.Sandbox,
      username: "postgres",
      password: "postgres",
      database: "chunkr_test",
      hostname: System.get_env("DB_HOST", "localhost"),
      port: System.get_env("DB_PORT", "5432")
    ]

    {:ok, Keyword.merge(config, test_config)}
  end

  use Chunkr, queries: Chunkr.TestQueries
end
