defmodule Chunkr.PaginationTest do
  use ExUnit.Case, async: true
  import Ecto.Query

  doctest Chunkr.Pagination

  alias Chunkr.{Page, TestRepo, User}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chunkr.TestRepo)
  end

  describe "Chunkr.Pagination.paginate/4" do
    test "with a query that already has ordering specified" do
      query = from(u in User, as: :user, order_by: [desc: u.id])
      {:error, message} = TestRepo.paginate(query, :single_field, :asc, first: 10)
      assert String.match?(message, ~r/must not be ordered prior/)
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
      assert %Page{
               opts: %{
                 planner: Chunkr.TestPaginationPlanner,
                 max_limit: 123_456
               }
             } =
               OtherRepo.paginate!(
                 from(u in User, as: :user),
                 :single_field,
                 :asc,
                 first: 10
               )
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
                 :another_strategy,
                 :asc,
                 first: 10,
                 planner: AnotherPaginationPlanner,
                 max_limit: 999_999
               )
    end
  end
end
