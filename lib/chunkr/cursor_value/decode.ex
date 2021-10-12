defprotocol Chunkr.CursorValue.Decode do
  @fallback_to_any true
  def convert(term)
end

defimpl Chunkr.CursorValue.Decode, for: Any do
  def convert(term), do: term
end
