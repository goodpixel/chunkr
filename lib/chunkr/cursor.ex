defmodule Chunkr.Cursor do
  @moduledoc """
  Behaviour for encoding and decoding of cursors.

  Allows the default Base64 cursor to be replaced via a custom cursor type specific to your
  application—for example, to allow signed cursors, etc. See `Chunkr.Cursor.Base64`

  Cursors are created from a list of values. Each individual value is encoded by the
  `Chunkr.CursorValue.Encode` protocol. Then the values are together encoded into
  cursor form via the `c:to_cursor/1` callback.

  Some types can be more efficiently encoded than simply relying on their default representation.
  For example, DateTime structs can be converted to Unix timestamps, which require far fewer bits.
  To achieve more efficient encoding of timestamps, you can provide the following protocol
  implementations for encoding and decoding:

      defimpl Chunkr.CursorValue.Encode, for: DateTime do
        def convert(%DateTime{} = datetime), do: {:dt, DateTime.to_unix(datetime, :microsecond)}
      end

      defimpl Chunkr.CursorValue.Decode, for: Tuple do
        def convert({:dt, unix_timestamp}), do: DateTime.from_unix!(unix_timestamp, :microsecond)
      end

  Any types that do not have a custom encoding will be passed through as is to the `c:to_cursor/1`
  callback.
  """

  @type cursor() :: binary()
  @type cursor_values() :: [any()]

  @doc """
  Invoked to translate a list of values into a cursor.

  Must return `{:ok, cursor}` if decoding was successful. On error, it must return
  `{:error, message}`.
  """
  @callback to_cursor(cursor_values :: cursor_values()) :: {:ok, cursor()} | {:error, binary()}

  @doc """
  Invoked to translate a cursor back to its initial values.

  Must return `{:ok, cursor_values}` if decoding was successful. On error, it must return
  `{:error, message}`.
  """
  @callback to_values(cursor :: cursor()) :: {:ok, cursor_values()} | {:error, binary()}

  @doc """
  Creates a cursor via the `c:to_cursor/1` callback.

  ## Example

      iex> Chunkr.Cursor.encode(["some", "value", 123], Chunkr.Cursor.Base64)
      {:ok, "g2wAAAADbQAAAARzb21lbQAAAAV2YWx1ZWF7ag=="}
  """
  @spec encode(cursor_values(), module()) :: {:ok, cursor()} | {:error, binary()}
  def encode(cursor_values, cursor_mod) when is_list(cursor_values) do
    cursor_values
    |> Enum.map(&Chunkr.CursorValue.Encode.convert/1)
    |> cursor_mod.to_cursor()
  end

  @doc """
  Same as `encode/2` but raises an error if creation of cursor fails.

  ## Example

      iex> Chunkr.Cursor.encode!(["some", "value", 123], Chunkr.Cursor.Base64)
      "g2wAAAADbQAAAARzb21lbQAAAAV2YWx1ZWF7ag=="
  """
  @spec encode!(cursor_values(), module()) :: cursor() | none()
  def encode!(cursor_values, cursor_mod) when is_list(cursor_values) do
    case encode(cursor_values, cursor_mod) do
      {:ok, cursor} -> cursor
      {:error, message} -> raise(ArgumentError, message)
    end
  end

  @doc """
  Decodes a cursor via the `c:to_values/1` callback.

  ## Example

      iex> Chunkr.Cursor.decode("g2wAAAADbQAAAARzb21lbQAAAAV2YWx1ZWF7ag==", Chunkr.Cursor.Base64)
      {:ok, ["some", "value", 123]}
  """
  @spec decode(cursor(), module()) :: {:ok, cursor_values()} | {:error, any()}
  def decode(cursor, cursor_mod) when is_binary(cursor) do
    case cursor_mod.to_values(cursor) do
      {:ok, cursor_values} -> {:ok, Enum.map(cursor_values, &Chunkr.CursorValue.Decode.convert/1)}
      {:error, message} -> {:error, message}
    end
  end

  @doc """
  Same as `decode/2` but raises an error for invalid cursors.

  ## Example

      iex> Chunkr.Cursor.decode!("g2wAAAADbQAAAARzb21lbQAAAAV2YWx1ZWF7ag==", Chunkr.Cursor.Base64)
      ["some", "value", 123]
  """
  @spec decode!(cursor(), module()) :: cursor_values() | none()
  def decode!(cursor, cursor_mod) do
    case decode(cursor, cursor_mod) do
      {:ok, cursor_values} -> cursor_values
      {:error, message} -> raise(ArgumentError, message)
    end
  end
end
