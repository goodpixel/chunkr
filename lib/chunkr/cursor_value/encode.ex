defprotocol Chunkr.CursorValue.Encode do
  @fallback_to_any true
  def convert(term)
end

defimpl Chunkr.CursorValue.Encode, for: Any do
  def convert(term), do: term
end
