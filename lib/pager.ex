defmodule Pager do
  @moduledoc """
  Documentation for Pager.
  """

  import Ecto.Query

  defmacro __using__(opts) do
    quote do
      @defaults unquote(opts)

      def paginate(queryable, sort, opts) do
        opts = Keyword.merge(@defaults, opts)
        Pager.paginate(queryable, sort, opts, __MODULE__)
      end
    end
  end

  @doc """

  """
  # TODO: extract repo
  # TODO: option: `include_cursor_values`

  # @spec paginate(Ecto.Queryable.t(), atom(), Keyword.t(), Pager.Config) ::
  def paginate(queryable, sort, opts, repo) do
    first = Keyword.get(opts, :first)
    last = Keyword.get(opts, :last)
    paging_direction = if first, do: :forward, else: :backward

    before_cursor = Keyword.get(opts, :before)
    after_cursor = Keyword.get(opts, :after)

    if first && last, do: raise("Cannot specify both first and last")
    requested_limit = first || last

    rows =
      queryable
      |> apply_where(paging_direction, after_cursor || before_cursor, sort)
      |> apply_order(paging_direction, sort)
      |> apply_select(sort)
      |> limit(^requested_limit + 1)
      |> repo.all()

    requested_rows = Enum.take(rows, requested_limit)

    rows_to_return =
      case paging_direction do
        :forward -> requested_rows
        :backward -> Enum.reverse(requested_rows)
      end

    %{
      records: rows_to_return |> Enum.map(fn {_cursor_values, record} -> record end),
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
  defp row_to_cursor({cursor_values, _record}), do: Pager.Cursor.encode(cursor_values)

  defp apply_where(query, :forward, nil, _custom_sort), do: query
  defp apply_where(query, :backward, nil, _custom_sort), do: query

  # FIXME: remove testquerys
  defp apply_where(query, :forward, cursor, sort) do
    Pager.TestQueries.beyond_cursor(query, cursor, sort, :forward)
  end

  defp apply_where(query, :backward, cursor, sort) do
    Pager.TestQueries.beyond_cursor(query, cursor, sort, :backward)
  end

  # FIXME: use config
  defp apply_order(query, :forward, sort) do
    Pager.TestQueries.order(query, sort)
  end

  defp apply_order(query, :backward, sort) do
    query
    |> apply_order(:forward, sort)
    |> Ecto.Query.reverse_order()
  end

    # FIXME: use config
  defp apply_select(queryable, sort) do
    Pager.TestQueries.with_cursor_fields(queryable, sort)
  end
end
