defmodule Chunkr.Cursor do
  @moduledoc """
  Create and decode opaque, Base64-encoded cursors.

  Cursors are created from a list of values. Each individual value for a cursor is encoded by the
  `Chunkr.CursorValue.Encode` protocol and decoded via the `Chunkr.CursorValue.Decode` protocol—which
  can be implemented to provide custom encoding of specific types. One primary example of this is
  encoding DateTime structs by first converting them to Unix timestamps, which require far fewer
  bits to represent the exact same timestamp.

  For example, to implement a more efficient encoding of timestamps, you could provide this:

      defimpl Chunkr.CursorValue.Encode, for: DateTime do
        def convert(%DateTime{} = datetime), do: {:dt, DateTime.to_unix(datetime, :microsecond)}
      end

      defimpl Chunkr.CursorValue.Decode, for: Tuple do
        def convert({:dt, unix_timestamp}), do: DateTime.from_unix!(unix_timestamp, :microsecond)
      end

  Any types that do not have a custom encoding specified will be passed through as is. The list
  of values for the cursor is then converted to binary before being Base64 encoded.
  """

  @type cursor_values() :: [any()]
  @type opaque_cursor() :: binary()

  @doc """
  Create an opaque, Base64-encoded cursor from `cursor_values`.

  ## Example

      iex> Chunkr.Cursor.encode(["something", ~U[2021-10-12 03:07:36.504502Z], 123])
      "g2wAAAADbQAAAAlzb21ldGhpbmdoAmQAAmR0bgcAtqDEJR_OBWF7ag=="
  """
  @spec encode(cursor_values()) :: opaque_cursor()
  def encode(cursor_values) when is_list(cursor_values) do
    cursor_values
    |> Enum.map(&Chunkr.CursorValue.Encode.convert/1)
    |> :erlang.term_to_binary()
    |> Base.url_encode64()
  end

  @doc """
  Same as `decode/1` but raises an error for invalid cursors.

  ## Example

      iex> Chunkr.Cursor.decode!("g2wAAAADbQAAAAlzb21ldGhpbmdoAmQAAmR0bgcAtqDEJR_OBWF7ag==")
      ["something", ~U[2021-10-12 03:07:36.504502Z], 123]
  """
  @spec decode!(opaque_cursor()) :: cursor_values() | none()
  def decode!(opaque_cursor) do
    case decode(opaque_cursor) do
      {:ok, cursor} -> cursor
      {:error, message} -> raise(ArgumentError, message)
    end
  end

  @doc """
  Decode an opaque cursor.

  ## Example

      iex> Chunkr.Cursor.decode("g2wAAAADbQAAAAlzb21ldGhpbmdoAmQAAmR0bgcAtqDEJR_OBWF7ag==")
      {:ok, ["something", ~U[2021-10-12 03:07:36.504502Z], 123]}
  """
  @spec decode(opaque_cursor()) :: {:ok, cursor_values()} | {:error, any()}
  def decode(opaque_cursor) when is_binary(opaque_cursor) do
    cursor_values(opaque_cursor)
  end

  defp cursor_values(opaque_cursor) do
    with {:ok, binary} <- base64_decode(opaque_cursor),
         {:ok, cursor_values} <- binary_to_term(binary) do
      if is_list(cursor_values) do
        {:ok, Enum.map(cursor_values, &Chunkr.CursorValue.Decode.convert/1)}
      else
        {:error, "Expected a list of values but got #{inspect(cursor_values)}"}
      end
    else
      {:error, :invalid_base64_value} ->
        {:error, "Error decoding base64-encoded string: '#{inspect(opaque_cursor)}'"}

      {:error, :invalid_term} ->
        {:error, "Unable to translate binary to an Elixir term: '#{inspect(opaque_cursor)}'"}
    end
  end

  defp base64_decode(string) do
    case Base.url_decode64(string) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, :invalid_base64_value}
    end
  end

  defp binary_to_term(binary) do
    try do
      {:ok, :erlang.binary_to_term(binary, [:safe])}
    rescue
      _ -> {:error, :invalid_term}
    end
  end
end
