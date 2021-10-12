defmodule Chunkr.Cursor.Base64 do
  @moduledoc """
  Create and decode opaque, Base64-encoded cursors.
  """

  @behaviour Chunkr.Cursor

  @doc """
  Create opaque cursor from `values`.

  ## Example

      iex> Chunkr.Cursor.Base64.to_cursor(["some", "value", 123])
      {:ok, "g2wAAAADbQAAAARzb21lbQAAAAV2YWx1ZWF7ag=="}
  """
  @impl true
  def to_cursor(values) do
    cursor =
      values
      |> :erlang.term_to_binary()
      |> Base.url_encode64()

    {:ok, cursor}
  end

  @doc """
  Decode opaque cursor into its original values.

  ## Example

      iex> Chunkr.Cursor.Base64.to_values("g2wAAAADbQAAAARzb21lbQAAAAV2YWx1ZWF7ag==")
      {:ok, ["some", "value", 123]}
  """
  @impl true
  def to_values(opaque_cursor) do
    with {:ok, binary} <- base64_decode(opaque_cursor),
         {:ok, cursor_values} <- binary_to_term(binary) do
      if is_list(cursor_values) do
        {:ok, cursor_values}
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
