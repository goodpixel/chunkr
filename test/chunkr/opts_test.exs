defmodule Chunkr.OptsTest do
  use ExUnit.Case, async: true
  alias Chunkr.Opts

  doctest Chunkr.Opts

  describe "Chunkr.Opts.new/3" do
    test "when paginating forwards without a cursor" do
      assert {:ok,
              %Opts{
                strategy: :first_name,
                disposition: :regular,
                paging_dir: :forward,
                cursor: nil,
                limit: 101
              }} =
               Opts.new(
                 by: :first_name,
                 repo: TestRepo,
                 planner: PlannerModule,
                 cursor_mod: Chunkr.Cursor.Base64,
                 first: 101,
                 max_limit: 200
               )
    end

    test "when paginating forwards with a cursor" do
      assert {:ok,
              %Opts{
                strategy: :first_name,
                disposition: :regular,
                paging_dir: :forward,
                cursor: "abc123",
                limit: 101
              }} =
               Opts.new(
                 by: :first_name,
                 repo: TestRepo,
                 planner: PlannerModule,
                 cursor_mod: Chunkr.Cursor.Base64,
                 first: 101,
                 after: "abc123",
                 max_limit: 200
               )
    end

    test "when paginating backwards without a cursor" do
      assert {:ok,
              %Opts{
                strategy: :middle_name,
                disposition: :regular,
                paging_dir: :backward,
                cursor: nil,
                limit: 99
              }} =
               Opts.new(
                 by: :middle_name,
                 repo: TestRepo,
                 planner: PlannerModule,
                 cursor_mod: Chunkr.Cursor.Base64,
                 last: 99,
                 max_limit: 100
               )
    end

    test "when paginating backwards with a cursor" do
      assert {:ok,
              %Opts{
                strategy: :middle_name,
                disposition: :regular,
                paging_dir: :backward,
                cursor: "def456",
                limit: 99
              }} =
               Opts.new(
                 by: :middle_name,
                 repo: TestRepo,
                 planner: PlannerModule,
                 cursor_mod: Chunkr.Cursor.Base64,
                 last: 99,
                 before: "def456",
                 max_limit: 100
               )
    end

    test "sets disposition correctly when inverting the specified ordering" do
      assert {:ok,
              %Opts{
                strategy: :first_name,
                disposition: :inverted,
                paging_dir: :forward,
                cursor: "abc123",
                limit: 101
              }} =
               Opts.new(
                 by: :first_name,
                 inverted: true,
                 repo: TestRepo,
                 planner: PlannerModule,
                 cursor_mod: Chunkr.Cursor.Base64,
                 first: 101,
                 after: "abc123",
                 max_limit: 200
               )
    end

    test "providing invalid page options results in an `{:invalid_opts, message}` error" do
      assert {:invalid_opts, _} = Opts.new(by: :middle_name, first: 99, last: 99)
      assert {:invalid_opts, _} = Opts.new(by: :middle_name, after: 99, before: 99)
      assert {:invalid_opts, _} = Opts.new(by: :middle_name, first: 99, before: 99)
      assert {:invalid_opts, _} = Opts.new(by: :middle_name, last: 99, after: 99)
    end

    test "requesting a negative number of rows in an `{:invalid_opts, message}` error" do
      opts = [
        by: :strategy,
        repo: TestRepo,
        planner: PlannerModule,
        cursor_mod: Chunkr.Cursor.Base64,
        max_limit: 100
      ]

      assert {:invalid_opts, _} = Opts.new([{:first, -1} | opts])
      assert {:ok, _} = Opts.new([{:first, 0} | opts])
    end

    test "requesting too many rows results in an `{:invalid_opts, message}` error" do
      opts = [
        by: :strategy,
        repo: TestRepo,
        planner: PlannerModule,
        cursor_mod: Chunkr.Cursor.Base64,
        max_limit: 5
      ]

      assert {:invalid_opts, _} = Opts.new([{:first, 6} | opts])
      assert {:ok, _} = Opts.new([{:first, 5} | opts])

      assert {:invalid_opts, _} = Opts.new([{:last, 6} | opts])
      assert {:ok, _} = Opts.new([{:last, 5} | opts])
    end

    test "when the same key is present multiple times it uses the first one added" do
      opts = [
        by: :strategy,
        repo: TestRepo,
        planner: PlannerModule,
        cursor_mod: Chunkr.Cursor.Base64,
        first: 101,
        max_limit: 100
      ]

      assert {:invalid_opts, _} = Opts.new(opts)
      assert {:invalid_opts, _} = Opts.new(opts ++ [{:max_limit, 101}])
      assert {:ok, _} = Opts.new([{:max_limit, 101} | opts])
    end
  end
end
