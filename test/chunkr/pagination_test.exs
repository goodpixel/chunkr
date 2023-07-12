defmodule Chunkr.PaginationTest do
  use ExUnit.Case, async: true
  import Ecto.Query

  doctest Chunkr.Pagination

  alias Chunkr.{Page, TestRepo, User}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chunkr.TestRepo)
  end

  describe "Chunkr.Pagination.paginate/3" do
    test "with a query that already has ordering specified" do
      query = from(u in User, as: :user, order_by: [desc: u.id])
      {:error, message} = TestRepo.paginate(query, by: :single_field, first: 10)
      assert String.match?(message, ~r/must not be ordered prior/)
    end

    test "honors `cursor_mod` for choosing a custom cursor implementation" do
      TestRepo.insert(%User{
        id: 123,
        public_id: Ecto.UUID.generate(),
        first_name: "Curious",
        last_name: "George"
      })

      query = from(u in User, as: :user)

      {:ok, %Page{end_cursor: cursor}} =
        TestRepo.paginate(query, by: :three_fields, first: 1, cursor_mod: Chunkr.JSONCursor)

      assert ["George", "Curious", 123] = Jason.decode!(cursor)
    end
  end

  defmodule OtherRepo do
    use Chunkr,
      planner: Chunkr.TestPaginationPlanner,
      max_limit: 123_456

    def all(_queryable), do: []
  end

  defmodule AnotherPaginationPlanner do
    use Chunkr.PaginationPlanner

    paginate_by :another_strategy do
      sort :asc, as(:user).id
    end
  end

  describe "opts" do
    test "respects config provided to `use Chunkr`" do
      assert %Page{opts: %{planner: Chunkr.TestPaginationPlanner, max_limit: 123_456}} =
               OtherRepo.paginate!(from(u in User, as: :user), by: :single_field, first: 10)
    end

    test "allows config to be overridden on the fly" do
      assert %Page{
               opts: %{
                 planner: AnotherPaginationPlanner,
                 max_limit: 999_999
               }
             } =
               OtherRepo.paginate!(
                 from(u in User, as: :user),
                 first: 10,
                 by: :another_strategy,
                 planner: AnotherPaginationPlanner,
                 max_limit: 999_999
               )
    end
  end
end
