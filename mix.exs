defmodule Chunkr.MixProject do
  use Mix.Project

  def project do
    [
      app: :chunkr,
      version: "0.1.0",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "Chunkr",
      source_url: "https://github.com/goodpixel/chunkr",
      # homepage_url: "http://YOUR_PROJECT_HOMEPAGE",
      docs: [
        main: "Chunkr", # The main page in the docs
        # logo: "path/to/logo.png",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ecto_sql, "~> 3.6"},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:postgrex, "~> 0.14", only: :test},
      {:stream_data, "~> 0.5", only: [:dev, :test]}
    ]
  end
end
