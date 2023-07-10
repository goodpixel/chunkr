import Config

config :logger, level: :warning

config :stream_data,
  max_runs: if(System.get_env("CI"), do: 200, else: 50)

config :chunkr, ecto_repos: [Chunkr.TestRepo]
