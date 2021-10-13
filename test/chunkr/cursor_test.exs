defmodule Chunkr.CursorTest do
  use ExUnit.Case, async: true
  alias Chunkr.Cursor

  doctest Chunkr.Cursor

  describe "Chunkr.Cursor.decode/1" do
    test "decodes a previously-encoded set of terms" do
      cursor_values = [:foo, "yep", ~U[2021-10-11 20:37:24.532520Z], 123, Ecto.UUID.generate()]

      assert {:ok, cursor_values} ==
               cursor_values
               |> Cursor.encode!(Cursor.Base64)
               |> Cursor.decode(Cursor.Base64)
    end
  end

  describe "Chunkr.Cursor.decode!/1" do
    test "decodes a previously-encoded set of terms" do
      cursor_values = [:foo, "yep", ~U[2021-10-11 20:37:24.532520Z], 123, Ecto.UUID.generate()]

      assert cursor_values ==
               cursor_values
               |> Cursor.encode!(Cursor.Base64)
               |> Cursor.decode!(Cursor.Base64)
    end
  end
end
