defmodule Pager do
  import Ecto.Query

  @moduledoc """
  Documentation for Pager.
  """

  @doc """

  """
  # TODO: extract repo

  # @spec paginate(Ecto.Queryable.t(), atom(), Keyword.t(), Pager.Config) ::
  def paginate(queryable, custom_sort, opts, repo) do
    first = Keyword.get(opts, :first)
    last = Keyword.get(opts, :last)
    paging_direction = if first, do: :forward, else: :backward

    before_cursor = Keyword.get(opts, :before)
    after_cursor = Keyword.get(opts, :after)

    if first && last, do: raise("Cannot specify both first and last")
    requested_limit = first || last

    rows =
      queryable
      |> apply_where(paging_direction, after_cursor || before_cursor, custom_sort)
      |> apply_order(paging_direction, custom_sort)
      |> apply_select(custom_sort)
      |> limit(^requested_limit + 1)
      |> repo.all()

    requested_rows = Enum.take(rows, requested_limit)

    rows_to_return =
      case paging_direction do
        :forward -> requested_rows
        :backward -> Enum.reverse(requested_rows)
      end

    %{
      records: rows_to_return |> Enum.map(fn {_cursor_fields, record} -> record end),
      has_previous_page:
        previous_page?(paging_direction, after_cursor, before_cursor, rows, requested_rows),
      has_next_page:
        next_page?(paging_direction, after_cursor, before_cursor, rows, requested_rows),
      start_cursor: rows_to_return |> List.first() |> row_to_cursor(),
      end_cursor: rows_to_return |> List.last() |> row_to_cursor()
    }
  end

  defp previous_page?(:forward, after_cursor, _before_cursor, _rows, _requested_rows),
    do: !!after_cursor

  defp previous_page?(:backward, _after_cursor, _before_cursor, rows, requested_rows),
    do: rows != requested_rows

  defp next_page?(:forward, _after_cursor, _before_cursor, rows, requested_rows),
    do: rows != requested_rows

  defp next_page?(:backward, _after_cursor, before_cursor, _rows, _requested_rows),
    do: !!before_cursor

  defp row_to_cursor(nil), do: nil
  defp row_to_cursor({fields, _record}), do: Pager.Cursor.encode(fields)

  defp apply_where(query, :forward, nil, _custom_sort), do: query

  # FIXME: remove testquerys
  defp apply_where(query, :forward, cursor, custom_sort) do
    Pager.TestQueries.beyond_cursor(query, cursor, custom_sort, :forward)
  end

  defp apply_where(query, :backward, nil, _custom_sort), do: query

  defp apply_where(query, :backward, cursor, _custom_sort) do
    [last_name, id] = Pager.Cursor.decode!(cursor)

    from(row in query,
      where:
        fragment("lower(coalesce(?, ?))", row.last_name, "zzz") <= ^last_name and
          (fragment("lower(coalesce(?, ?))", row.last_name, "zzz") < ^last_name or
             (fragment("lower(coalesce(?, ?))", row.last_name, "zzz") == ^last_name and
                row.id < ^id))
    )
  end

  # FIXME: use config
  defp apply_order(query, :forward, custom_sort) do
    Pager.TestQueries.order(query, custom_sort)
  end

  defp apply_order(query, :backward, custom_sort) do
    query
    |> apply_order(:forward, custom_sort)
    |> Ecto.Query.reverse_order()
  end

    # FIXME: use config
  defp apply_select(queryable, custom_sort) do
    Pager.TestQueries.with_cursor_fields(queryable, custom_sort)
  end
end
