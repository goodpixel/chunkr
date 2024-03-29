defmodule Chunkr.Cursor.Base64Test do
  use ExUnit.Case, async: true
  alias Chunkr.Cursor.Base64

  doctest Chunkr.Cursor.Base64

  describe "Chunkr.Cursor.Base64.to_values/1" do
    test "decodes a previously-encoded set of terms" do
      values = [:foo, "yep", ~U[2021-10-11 20:37:24.532520Z], 123, Ecto.UUID.generate()]

      assert {:ok, cursor} = Base64.to_cursor(values)
      assert {:ok, ^values} = Base64.to_values(cursor)
    end

    test "returns an error if a cursor can't be Base64 decoded" do
      invalid_base64 = "Nope, nope, nope"
      assert {:error, message} = Base64.to_values(invalid_base64)
      assert String.match?(message, ~r/Error decoding base64-encoded string/)
    end

    # Atoms are never deleted while the VM runs, so we can't allow user input to
    # result in the creation of atoms. If we did, we'd be open to attacks that
    # generate atoms until the system can't cope.
    test "returns an error if a cursor contains an atom that does not yet exist" do
      new_atom = <<131, 119, 20, "💣💥🧨💀🙀">>
      dangerous_cursor = Base.url_encode64(new_atom)
      assert {:error, message} = Base64.to_values(dangerous_cursor)
      assert String.match?(message, ~r/Unable to translate binary/)
    end
  end
end
