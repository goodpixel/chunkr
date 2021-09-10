defmodule PagerTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Ecto.Query
  import Pager.PaginationHelpers

  doctest Pager

  alias Pager.User

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Pager.TestRepo)
  end

  describe "QUERY NAME" do
    property "provides an overall result set that matches the non-paginated query when paging forward" do
      check all(
              limit <- positive_integer(),
              rows <- list_of(user_attrs(), max_length: 20)
            ) do
        queries_module = Pager.TestQueries
        custom_sort = :last_name_asc
        repo = Pager.TestRepo

        repo.insert_all(User, rows)

        query = from u in User, as: :user
        ordered_query = queries_module.order(query, custom_sort)
        expected_results = repo.all(ordered_query)
        expected_count = repo.aggregate(query, :count)

        paginated_results =
          query
          |> page_thru(custom_sort, first: limit)
          |> Enum.flat_map(& &1.records)

        assert expected_count == length(paginated_results)
        assert expected_results == paginated_results

        User |> repo.delete_all()
      end
    end

    property "provides an overall result set that matches the non-paginated query when paging backward" do
      check all(
              limit <- positive_integer(),
              count <- integer(0..3)
            ) do
        queries_module = Pager.TestQueries
        custom_sort = :last_name_asc
        repo = Pager.TestRepo

        rows = Enum.take(user_attrs(), count)
        repo.insert_all(User, rows, returning: true)

        query = from u in User, as: :user
        ordered_query = queries_module.order(query, custom_sort)
        expected_results = repo.all(ordered_query)
        expected_count = repo.aggregate(query, :count)

        paginated_results =
          query
          |> page_thru(custom_sort, last: limit)
          |> Enum.reverse()
          |> Enum.flat_map(& &1.records)

        assert expected_count == length(paginated_results)
        assert expected_results == paginated_results

        User |> repo.delete_all()
      end
    end

    property "pages have proper sizes and metadata" do
      check all(
              limit <- positive_integer(),
              rows <- list_of(user_attrs(), max_length: 20),
              paging_direction <- one_of([constant(:forward), constant(:backward)])
            ) do
        custom_sort = :last_name_asc
        repo = Pager.TestRepo

        repo.insert_all(User, rows)
        query = from u in User, as: :user
        total_count = repo.aggregate(query, :count)

        opts =
          case paging_direction do
            :forward -> [first: limit]
            :backward -> [last: limit]
          end

        final_page_size =
          case Integer.mod(total_count, limit) do
            0 -> limit
            leftover -> leftover
          end

        final_page_number = ceil(total_count / limit)

        assert_page_size = fn
          page, 1 ->
            if total_count < limit do
              assert total_count == length(page)
            else
              assert limit == length(page)
            end

          page, ^final_page_number ->
            actual_page_size = length(page)

            assert final_page_size == length(page),
                   "Expected final page to have #{final_page_size} results, but it had #{actual_page_size}."

          page, page_number ->
            actual_page_size = length(page)

            assert limit == actual_page_size,
                   "Expected page #{page_number} of #{final_page_number} to have #{limit} results, but it had #{actual_page_size}."
        end

        assert_metadata = fn
          page, 1 ->
            case paging_direction do
              :forward ->
                assert false == page.has_previous_page
                assert (final_page_number > 1) == page.has_next_page
              :backward ->
                assert (final_page_number > 1) == page.has_previous_page
                assert false == page.has_next_page
            end

          page, ^final_page_number ->
            case paging_direction do
              :forward ->
                assert (final_page_number > 1) == page.has_previous_page
                assert false == page.has_next_page
              :backward ->
                assert false == page.has_previous_page
                assert (final_page_number > 1) == page.has_next_page
            end

          page, number ->
            assert page.has_previous_page, "Expected `has_previous_page` to be `true` for intermediate page #{number} of #{final_page_number}."
            assert page.has_next_page, "Expected `has_next_page` to be `true` for intermediate page #{number} of #{final_page_number}."
        end

        query
        |> page_thru(custom_sort, opts)
        |> Stream.with_index(1)
        |> Enum.each(fn {page, page_number} ->
          assert_page_size.(page.records, page_number)
          assert_metadata.(page, page_number)
        end)

        User |> repo.delete_all()
      end
    end
  end
end
