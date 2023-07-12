defmodule Chunkr.PaginationHelpers do
  @moduledoc false

  use ExUnitProperties
  import ExUnit.Assertions, only: [assert: 1]
  alias Chunkr.Page

  @max_page_size 100

  def verify_pagination(repo, query, opts, expected_results, expected_count) do
    verify_forward(repo, query, opts, expected_results, expected_count)
    verify_backward(repo, query, opts, expected_results, expected_count)
    verify_pages(repo, query, opts, expected_count)
  end

  defp verify_forward(repo, query, opts, expected_results, expected_count) do
    inverted = Keyword.get(opts, :inverted, false)
    strategy = Keyword.fetch!(opts, :by)

    check all page_size <- integer(1..@max_page_size) do
      paginated_results =
        repo
        |> page_thru(query, by: strategy, inverted: inverted, first: page_size)
        |> Enum.flat_map(fn page -> Page.records(page) end)

      assert expected_results == paginated_results
      assert expected_count == length(paginated_results)
    end
  end

  defp verify_backward(repo, query, opts, expected_results, expected_count) do
    inverted = Keyword.get(opts, :inverted, false)
    strategy = Keyword.fetch!(opts, :by)

    check all page_size <- integer(1..@max_page_size) do
      paginated_results =
        repo
        |> page_thru(query, by: strategy, inverted: inverted, last: page_size)
        |> Enum.reverse()
        |> Enum.flat_map(fn page -> Page.records(page) end)

      assert expected_results == paginated_results
      assert expected_count == length(paginated_results)
    end
  end

  defp verify_pages(repo, query, opts, expected_count) do
    inverted = Keyword.get(opts, :inverted, false)
    strategy = Keyword.fetch!(opts, :by)

    check all page_size <- integer(1..@max_page_size),
              paging_direction <- one_of([constant(:forward), constant(:backward)]) do
      opts =
        case paging_direction do
          :forward -> [by: strategy, inverted: inverted, first: page_size]
          :backward -> [by: strategy, inverted: inverted, last: page_size]
        end

      final_page = final_page_number(expected_count, page_size)

      repo
      |> page_thru(query, opts)
      |> Stream.with_index(1)
      |> Enum.each(fn {page, page_num} ->
        assert has_previous_page?(paging_direction, page_num, final_page) ==
                 page.has_previous_page

        assert has_next_page?(paging_direction, page_num, final_page) == page.has_next_page
        assert page_size(page_num, expected_count, page_size) == length(page.raw_results)
      end)
    end
  end

  defp page_thru(repo, query, opts) do
    paging_dir =
      cond do
        Keyword.get(opts, :first) -> :forward
        Keyword.get(opts, :last) -> :backward
      end

    repo.paginate!(query, opts)
    |> Stream.unfold(fn
      %Page{has_next_page: true, end_cursor: c} = page when paging_dir == :forward ->
        opts = Keyword.put(opts, :after, c)
        next_result = repo.paginate!(query, opts)
        {page, next_result}

      %Page{has_next_page: false} = page when paging_dir == :forward ->
        {page, :done}

      %Page{has_previous_page: true, start_cursor: c} = page when paging_dir == :backward ->
        opts = Keyword.put(opts, :before, c)
        next_result = repo.paginate!(query, opts)
        {page, next_result}

      %Page{has_previous_page: false} = page when paging_dir == :backward ->
        {page, :done}

      :done ->
        nil
    end)
  end

  defp page_size(_page_number, 0, _page_size), do: 0

  defp page_size(page_number, total, page_size) do
    final_page = final_page_number(total, page_size)

    if page_number == final_page do
      final_page_size(total, page_size)
    else
      page_size
    end
  end

  defp final_page_number(total_count, page_size), do: ceil(total_count / page_size)

  defp final_page_size(total_count, page_size) do
    case Integer.mod(total_count, page_size) do
      0 -> page_size
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
