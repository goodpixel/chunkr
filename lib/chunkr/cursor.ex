defmodule Chunkr.Cursor do
  @moduledoc """
  Create and decode opaque, Base64-encoded cursors.
  """

  @type cursor_values() :: [any()]
  @type opaque_cursor() :: binary()

  @doc """
  Create an opaque, Base64-encoded cursor from `cursor_values`.
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
