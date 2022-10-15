defmodule Chunkr.CursorValue.EncodeTest do
  use ExUnit.Case, async: true
  alias Chunkr.CursorValue.Encode

  doctest Chunkr.CursorValue.Encode

  describe "Chunkr.CursorValue.Encode.convert/1" do
    test "returns the initial value unchanged by default" do
      assert :foo = Encode.convert(:foo)
      assert "bar" = Encode.convert("bar")
      assert 123 = Encode.convert(123)
      assert %{foo: :bar} = Encode.convert(%{foo: :bar})
    end

    # See /test/support/custom_encoding.ex
    test "honors custom encoding of cursor values" do
      assert {:dt, 1_665_614_913_437_848} = Encode.convert(~U[2022-10-12 22:48:33.437848Z])
    end
  end
end
