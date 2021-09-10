defmodule Pager.PaginationHelpers do
  use ExUnitProperties
  import ExUnit.Assertions
  import Ecto.Query

  @doc """
  Streams pages for the entire result set starting with the given opts
  """
  def page_thru(query, custom_sort, opts) do
    dir =
      case opts do
        [first: _limit] -> :forward
        [last: _limit] -> :backward
      end

    Pager.paginate(query, custom_sort, opts, Pager.TestRepo)
    |> Stream.unfold(fn
      %{has_next_page: true, end_cursor: c} = page when dir == :forward ->
        opts = Keyword.put(opts, :after, c)
        next_result = Pager.paginate(query, custom_sort, opts, Pager.TestRepo)
        {page, next_result}

      %{has_next_page: false} = page when dir == :forward ->
        {page, :done}

      %{has_previous_page: true, start_cursor: c} = page when dir == :backward ->
        opts = Keyword.put(opts, :before, c)
        next_result = Pager.paginate(query, custom_sort, opts, Pager.TestRepo)
        {page, next_result}

      %{has_previous_page: false} = page when dir == :backward ->
        {page, :done}

      :done ->
        nil
    end)
  end

  def user_attrs() do
    gen all(
          first_name <- one_of([constant(nil), string(:ascii)]),
          middle_name <- one_of([constant(nil), string(:ascii)]),
          last_name <- one_of([constant(nil), string(:ascii)]),
          inserted_at <- datetime(),
          updated_at <- datetime()
        ) do
      %{
        first_name: first_name,
        middle_name: middle_name,
        last_name: last_name,
        inserted_at: inserted_at,
        updated_at: updated_at
      }
    end
  end

  @microseconds_per_year 365 * 24 * 60 * 60 * 1000 * 1000

  # generates a date between 1,000 years ago and 1,000 years from now
  defp datetime() do
    now = DateTime.utc_now()

    earliest =
      DateTime.add(now, -1_000 * @microseconds_per_year, :microsecond)
      |> DateTime.to_unix(:microsecond)

    latest =
      DateTime.add(now, 1_000 * @microseconds_per_year, :microsecond)
      |> DateTime.to_unix(:microsecond)

    gen all(int <- integer(earliest..latest)) do
      DateTime.from_unix!(int, :microsecond)
    end
  end
end
