import Config

config :logger, level: :warn

config :stream_data,
  max_runs: if(System.get_env("CI"), do: 200, else: 50)
