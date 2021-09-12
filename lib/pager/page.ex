defmodule Pager.Page do
  @enforce_keys [:records, :has_previous_page, :has_next_page, :start_cursor, :end_cursor]
  defstruct [:records, :has_previous_page, :has_next_page, :start_cursor, :end_cursor]
end
