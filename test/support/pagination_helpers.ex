defmodule Chunkr.PaginationHelpers do
  @moduledoc false

  use ExUnitProperties
  import ExUnit.Assertions, only: [assert: 1]
  alias Chunkr.Page

  @max_limit 100

  def verify_pagination(repo, query, strategy, sort_dir, expected_results, expected_count) do
    verify_forward(repo, query, strategy, sort_dir, expected_results, expected_count)
    verify_backward(repo, query, strategy, sort_dir, expected_results, expected_count)
    verify_pages(repo, query, strategy, sort_dir, expected_count)
  end

  defp verify_forward(repo, query, strategy, sort_dir, expected_results, expected_count) do
    check all limit <- integer(1..@max_limit) do
      paginated_results =
        repo
        |> page_thru(query, strategy, sort_dir, first: limit)
        |> Enum.flat_map(fn page -> Page.records(page) end)

      assert expected_results == paginated_results
      assert expected_count == length(paginated_results)
    end
  end

  defp verify_backward(repo, query, strategy, sort_dir, expected_results, expected_count) do
    check all limit <- integer(1..@max_limit) do
      paginated_results =
        repo
        |> page_thru(query, strategy, sort_dir, last: limit)
        |> Enum.reverse()
        |> Enum.flat_map(fn page -> Page.records(page) end)

      assert expected_results == paginated_results
      assert expected_count == length(paginated_results)
    end
  end

  defp verify_pages(repo, query, strategy, sort_dir, expected_count) do
    check all limit <- integer(1..@max_limit),
              paging_direction <- one_of([constant(:forward), constant(:backward)]) do
      opts =
        case paging_direction do
          :forward -> [first: limit]
          :backward -> [last: limit]
        end

      final_page = final_page_number(expected_count, limit)

      repo
      |> page_thru(query, strategy, sort_dir, opts)
      |> Stream.with_index(1)
      |> Enum.each(fn {page, page_num} ->
        assert has_previous_page?(paging_direction, page_num, final_page) ==
                 page.has_previous_page

        assert has_next_page?(paging_direction, page_num, final_page) == page.has_next_page
        assert page_size(page_num, expected_count, limit) == length(page.raw_results)
      end)
    end
  end

  @doc """
  Streams pages for the entire result set starting with the given opts
  """
  def page_thru(repo, query, strategy, sort_dir, opts) do
    paging_dir =
      case opts do
        [first: _limit] -> :forward
        [last: _limit] -> :backward
      end

    repo.paginate!(query, strategy, sort_dir, opts)
    |> Stream.unfold(fn
      %Page{has_next_page: true, end_cursor: c} = page when paging_dir == :forward ->
        opts = Keyword.put(opts, :after, c)
        next_result = repo.paginate!(query, strategy, sort_dir, opts)
        {page, next_result}

      %Page{has_next_page: false} = page when paging_dir == :forward ->
        {page, :done}

      %Page{has_previous_page: true, start_cursor: c} = page when paging_dir == :backward ->
        opts = Keyword.put(opts, :before, c)
        next_result = repo.paginate!(query, strategy, sort_dir, opts)
        {page, next_result}

      %Page{has_previous_page: false} = page when paging_dir == :backward ->
        {page, :done}

      :done ->
        nil
    end)
  end

  defp page_size(_page_number, 0, _limit), do: 0

  defp page_size(page_number, total, limit) do
    final_page = final_page_number(total, limit)

    if page_number == final_page do
      final_page_size(total, limit)
    else
      limit
    end
  end

  defp final_page_number(total_count, limit), do: ceil(total_count / limit)

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
  defp has_previous_page?(:forward, 1, _last_page), do: false
  defp has_previous_page?(:forward, _current_page, _last_page), do: true
  defp has_previous_page?(:backward, current_page, last_page), do: current_page < last_page

  defp has_next_page?(:forward, current_page, last_page), do: current_page < last_page
  defp has_next_page?(:backward, 1, _last_page), do: false
  defp has_next_page?(:backward, _current_page, _last_page), do: true
end
