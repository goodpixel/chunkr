defprotocol Chunkr.CursorValue.Decode do
  @moduledoc """
  Allows for custom conversion of cursor values.

  See `Chunkr.Cursor`.
  """

  @fallback_to_any true
  def convert(term)
end

defimpl Chunkr.CursorValue.Decode, for: Any do
  def convert(term), do: term
end
