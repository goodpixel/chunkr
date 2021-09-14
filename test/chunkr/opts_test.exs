defmodule Chunkr.OptsTest do
  use ExUnit.Case, async: true
  alias Chunkr.{Opts, User}

  doctest Chunkr.Opts

  describe "Chunkr.Opts.new/3" do
    test "when paginating forwards without a cursor" do
      assert {:ok,
              %Opts{
                query: User,
                sort: :first_name,
                cursor: nil,
                paging_dir: :forward,
                limit: 101
              }} = Opts.new(User, :first_name, first: 101)
    end

    test "when paginating forwards with a cursor" do
      assert {:ok,
              %Opts{
                query: User,
                sort: :first_name,
                cursor: "abc123",
                paging_dir: :forward,
                limit: 101
              }} = Opts.new(User, :first_name, first: 101, after: "abc123")
    end

    test "when paginating backwards without a cursor" do
      assert {:ok,
              %Opts{
                query: User,
                sort: :middle_name,
                cursor: nil,
                paging_dir: :backward,
                limit: 99
              }} = Opts.new(User, :middle_name, last: 99)
    end

    test "when paginating backwards with a cursor" do
      assert {:ok,
              %Opts{
                query: User,
                sort: :middle_name,
                cursor: "def456",
                paging_dir: :backward,
                limit: 99
              }} = Opts.new(User, :middle_name, last: 99, before: "def456")
    end

    test "when providing invalid page options" do
      assert {:invalid_opts, _} = Opts.new(User, :middle_name, first: 99, last: 99)
      assert {:invalid_opts, _} = Opts.new(User, :middle_name, after: 99, before: 99)
      assert {:invalid_opts, _} = Opts.new(User, :middle_name, first: 99, before: 99)
      assert {:invalid_opts, _} = Opts.new(User, :middle_name, last: 99, after: 99)
    end
  end
end
