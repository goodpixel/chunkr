defmodule Chunkr.OptsTest do
  use ExUnit.Case, async: true
  alias Chunkr.{Opts, User}

  doctest Chunkr.Opts

  describe "Chunkr.Opts.new/3" do
    test "when paginating forwards without a cursor" do
      assert {:ok,
              %Opts{
                query: User,
                strategy: :first_name,
                sort_dir: :asc,
                paging_dir: :forward,
                cursor: nil,
                limit: 101
              }} =
               Opts.new(User, :first_name, :asc,
                 repo: TestRepo,
                 queries: QueriesModule,
                 first: 101,
                 max_limit: 200
               )
    end

    test "when paginating forwards with a cursor" do
      assert {:ok,
              %Opts{
                query: User,
                strategy: :first_name,
                sort_dir: :desc,
                paging_dir: :forward,
                cursor: "abc123",
                limit: 101
              }} =
               Opts.new(User, :first_name, :desc,
                 repo: TestRepo,
                 queries: QueriesModule,
                 first: 101,
                 after: "abc123",
                 max_limit: 200
               )
    end

    test "when paginating backwards without a cursor" do
      assert {:ok,
              %Opts{
                query: User,
                strategy: :middle_name,
                sort_dir: :asc,
                paging_dir: :backward,
                cursor: nil,
                limit: 99
              }} =
               Opts.new(User, :middle_name, :asc,
                 repo: TestRepo,
                 queries: QueriesModule,
                 last: 99,
                 max_limit: 100
               )
    end

    test "when paginating backwards with a cursor" do
      assert {:ok,
              %Opts{
                query: User,
                strategy: :middle_name,
                sort_dir: :asc,
                paging_dir: :backward,
                cursor: "def456",
                limit: 99
              }} =
               Opts.new(User, :middle_name, :asc,
                 repo: TestRepo,
                 queries: QueriesModule,
                 last: 99,
                 before: "def456",
                 max_limit: 100
               )
    end

    test "providing invalid page options results in an `{:invalid_opts, message}` error" do
      assert {:invalid_opts, _} = Opts.new(User, :middle_name, :desc, first: 99, last: 99)
      assert {:invalid_opts, _} = Opts.new(User, :middle_name, :desc, after: 99, before: 99)
      assert {:invalid_opts, _} = Opts.new(User, :middle_name, :desc, first: 99, before: 99)
      assert {:invalid_opts, _} = Opts.new(User, :middle_name, :desc, last: 99, after: 99)
    end

    test "requesting a negative number of rows in an `{:invalid_opts, message}` error" do
      opts = [repo: TestRepo, queries: QueriesModule, max_limit: 100]
      assert {:invalid_opts, _} = Opts.new(User, :strategy, :asc, [{:first, -1} | opts])
      assert {:ok, _} = Opts.new(User, :strategy, :asc, [{:first, 0} | opts])
    end

    test "requesting too many rows results in an `{:invalid_opts, message}` error" do
      opts = [repo: TestRepo, queries: QueriesModule, max_limit: 5]

      assert {:invalid_opts, _} = Opts.new(User, :strategy, :asc, [{:first, 6} | opts])
      assert {:ok, _} = Opts.new(User, :strategy, :asc, [{:first, 5} | opts])

      assert {:invalid_opts, _} = Opts.new(User, :strategy, :asc, [{:last, 6} | opts])
      assert {:ok, _} = Opts.new(User, :strategy, :asc, [{:last, 5} | opts])
    end

    test "when the same key is present multiple times it uses the first one added" do
      opts = [repo: TestRepo, queries: QueriesModule, first: 101, max_limit: 100]

      assert {:invalid_opts, _} = Opts.new(User, :strategy, :asc, opts)
      assert {:invalid_opts, _} = Opts.new(User, :strategy, :asc, opts ++ [{:max_limit, 101}])
      assert {:ok, _} = Opts.new(User, :strategy, :asc, [{:max_limit, 101} | opts])
    end
  end
end
