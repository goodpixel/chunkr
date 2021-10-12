# This is for test purposes only!
defmodule Chunkr.JSONCursor do
  @moduledoc false

  @behaviour Chunkr.Cursor

  @impl true
  def to_cursor(cursor_values), do: Jason.encode(cursor_values)

  @impl true
  def to_values(cursor), do: Jason.decode(cursor)
end
