defmodule Chunkr.CursorValue.DecodeTest do
  use ExUnit.Case, async: true
  alias Chunkr.CursorValue.Decode

  doctest Chunkr.CursorValue.Decode

  describe "Chunkr.CursorValue.Decode.convert/1" do
    test "returns the initial value unchanged by default" do
      assert :foo = Decode.convert(:foo)
      assert "bar" = Decode.convert("bar")
      assert 123 = Decode.convert(123)
      assert %{foo: :bar} = Decode.convert(%{foo: :bar})
    end

    # See /test/support/custom_encoding.ex
    test "honors custom encoding of cursor values" do
      assert ~U[2022-10-12 22:48:33.437848Z] = Decode.convert({:dt, 1_665_614_913_437_848})
    end
  end
end
