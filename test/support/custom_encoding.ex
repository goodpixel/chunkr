# These are samples only. They do, however, get exercised by any tests involving these types
# so that we can verify that what we're recommending actually works…
defimpl Chunkr.CursorValue.Encode, for: DateTime do
  def convert(%DateTime{} = datetime), do: {:dt, DateTime.to_unix(datetime, :microsecond)}
end

defimpl Chunkr.CursorValue.Decode, for: Tuple do
  def convert({:dt, usec}) when is_integer(usec), do: DateTime.from_unix!(usec, :microsecond)
end
