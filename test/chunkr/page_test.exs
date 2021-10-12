defmodule Chunkr.PageTest do
  use ExUnit.Case, async: true
  alias Chunkr.{Cursor, Opts, Page}

  doctest Chunkr.Page

  defmodule MockRepo do
    def aggregate(User, :count) do
      1_234_567
    end
  end

  defp fake_page() do
    opts = %Opts{repo: MockRepo, planner: SomeModule, query: User, cursor_mod: Cursor.Base64}

    %Page{
      raw_results: [{[:cursor_val_1], :foo_record}, {[:cursor_val_2], :bar_record}],
      has_previous_page: :maybe,
      has_next_page: :maybe_not,
      start_cursor: "sure",
      end_cursor: "hrpmh",
      opts: opts
    }
  end

  describe "Chunkr.Page.total_count/1" do
    test "queries the total non-paginated count" do
      page = fake_page()
      assert 1_234_567 = Page.total_count(page)
    end
  end

  describe "Chunkr.Page.records/1" do
    test "returns just the records" do
      page = fake_page()
      assert [:foo_record, :bar_record] = Page.records(page)
    end
  end

  describe "Chunkr.Page.cursors_and_records/1" do
    test "returns opaque cursors alongside their corresponding records" do
      page = fake_page()
      cursor1 = Cursor.encode([:cursor_val_1], Cursor.Base64)
      cursor2 = Cursor.encode([:cursor_val_2], Cursor.Base64)
      assert [{^cursor1, :foo_record}, {^cursor2, :bar_record}] = Page.cursors_and_records(page)
    end
  end
end
