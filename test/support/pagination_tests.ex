defmodule Chunkr.PaginationTests do
  import ExUnit.Assertions

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro verify_pagination(query_repo, queries_module, sort_name, opts \\ []) do
    pre_hook = Keyword.get(opts, :pre, fn -> nil end)
    subject_query = Keyword.fetch!(opts, :query)
    post_hook = Keyword.get(opts, :post, fn -> nil end)

    quote do
      describe "#{inspect(unquote(sort_name))}" do
        property "provides an overall result set that matches the non-paginated query when paging forward" do
          check all(
                  limit <- positive_integer(),
                  user_attrs <- list_of(user_attrs(), max_length: 30),
                  phone_attrs <- list_of(phone_attrs(), max_length: 30)
                ) do
            unquote(pre_hook).(%{users: user_attrs, phones: phone_attrs})
            custom_sort = unquote(sort_name)
            repo = unquote(query_repo)
            query = unquote(subject_query)
            queries_mod = unquote(queries_module)

            expected_results =
              query
              |> queries_mod.order(custom_sort)
              |> repo.all()

            expected_count = repo.aggregate(query, :count)

            paginated_results =
              repo
              |> page_thru(query, custom_sort, first: limit)
              |> Enum.flat_map(fn page ->
                Enum.map(page.raw_results, fn {_cursor_values, record} -> record end)
              end)

            assert expected_count == length(paginated_results)
            assert expected_results == paginated_results
            unquote(post_hook).()
          end
        end

        property "provides an overall result set that matches the non-paginated query when paging backward" do
          check all(
                  limit <- positive_integer(),
                  user_attrs <- list_of(user_attrs(), max_length: 30),
                  phone_attrs <- list_of(phone_attrs(), max_length: 30)
                ) do
            unquote(pre_hook).(%{users: user_attrs, phones: phone_attrs})
            custom_sort = unquote(sort_name)
            repo = unquote(query_repo)
            query = unquote(subject_query)
            queries_mod = unquote(queries_module)

            expected_results =
              query
              |> queries_mod.order(custom_sort)
              |> repo.all()

            expected_count = repo.aggregate(query, :count)

            paginated_results =
              repo
              |> page_thru(query, custom_sort, last: limit)
              |> Enum.reverse()
              |> Enum.flat_map(fn page ->
                Enum.map(page.raw_results, fn {_cursor_values, record} -> record end)
              end)

            assert expected_count == length(paginated_results)
            assert expected_results == paginated_results

            unquote(post_hook).()
          end
        end

        property "pages have proper sizes and metadata" do
          check all(
                  limit <- positive_integer(),
                  user_attrs <- list_of(user_attrs(), max_length: 30),
                  phone_attrs <- list_of(phone_attrs(), max_length: 30),
                  direction <- one_of([constant(:forward), constant(:backward)])
                ) do
            unquote(pre_hook).(%{users: user_attrs, phones: phone_attrs})
            custom_sort = unquote(sort_name)
            repo = unquote(query_repo)
            query = unquote(subject_query)
            queries_mod = unquote(queries_module)

            total_count = repo.aggregate(query, :count)

            opts =
              case direction do
                :forward -> [first: limit]
                :backward -> [last: limit]
              end

            final_page = final_page_number(total_count, limit)

            repo
            |> page_thru(query, custom_sort, opts)
            |> Stream.with_index(1)
            |> Enum.each(fn {page, num} ->
              assert has_previous_page?(direction, num, final_page) == page.has_previous_page
              assert has_next_page?(direction, num, final_page) == page.has_next_page
              assert page_size(num, total_count, limit) == length(page.raw_results)
            end)

            unquote(post_hook).()
          end
        end
      end
    end
  end

  def page_size(_page_number, 0, _limit), do: 0

  def page_size(page_number, total, limit) do
    final_page = final_page_number(total, limit)

    if page_number == final_page do
      final_page_size(total, limit)
    else
      limit
    end
  end

  def final_page_number(total_count, limit), do: ceil(total_count / limit)

  defp final_page_size(total_count, limit) do
    case Integer.mod(total_count, limit) do
      0 -> limit
      leftover -> leftover
    end
  end

  # Note that when paginating backward from the end of the result set,
  # page "1" is the first page we encounter and therefore represents the
  # tail end of the full, unpaginated result set.
  #
  # Likewise, when paginating backward, the "final" page represents the
  # beginning of the full, unpaginated result set.
  def has_previous_page?(:forward, 1, _last_page), do: false
  def has_previous_page?(:forward, _current_page, _last_page), do: true
  def has_previous_page?(:backward, current_page, last_page), do: current_page < last_page

  def has_next_page?(:forward, current_page, last_page), do: current_page < last_page
  def has_next_page?(:backward, 1, _last_page), do: false
  def has_next_page?(:backward, _current_page, _last_page), do: true
end
