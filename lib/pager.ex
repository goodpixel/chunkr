defmodule Pager do
  @moduledoc """
  Documentation for Pager.
  """

  require Ecto.Query

  defmacro __using__(config) do
    quote do
      @default_config Pager.Config.new([{:repo, __MODULE__} | unquote(config)])

      def paginate(queryable, sort, opts) do
        Pager.paginate(queryable, sort, opts, @default_config)
      end
    end
  end

  @doc """

  """
  # @spec paginate(Ecto.Queryable.t(), atom(), Keyword.t(), Pager.Config) ::
  def paginate(queryable, sort, opts, config) do
    first = Keyword.get(opts, :first)
    last = Keyword.get(opts, :last)

    paging_direction = if first, do: :forward, else: :backward

    before_cursor = Keyword.get(opts, :before)
    after_cursor = Keyword.get(opts, :after)

    if first && last, do: raise("Cannot specify both first and last")
    requested_limit = first || last

    rows =
      queryable
      |> apply_where(sort, paging_direction, before_cursor || after_cursor, config)
      |> apply_order(sort, paging_direction, config)
      |> apply_select(sort, config)
      |> apply_limit(requested_limit + 1, config)
      |> config.repo.all()

    requested = Enum.take(rows, requested_limit)

    rows_to_return =
      case paging_direction do
        :forward -> requested
        :backward -> Enum.reverse(requested)
      end

    %Pager.Page{
      raw_results: rows_to_return,
      has_previous_page: has_previous_page?(paging_direction, after_cursor, rows, requested),
      has_next_page: has_next_page?(paging_direction, before_cursor, rows, requested),
      start_cursor: rows_to_return |> List.first() |> row_to_cursor(),
      end_cursor: rows_to_return |> List.last() |> row_to_cursor()
    }
  end

  defp has_previous_page?(:forward, cursor, _rows, _requested_rows), do: !!cursor
  defp has_previous_page?(:backward, _cursor, rows, requested_rows), do: rows != requested_rows

  defp has_next_page?(:forward, _cursor, rows, requested_rows), do: rows != requested_rows
  defp has_next_page?(:backward, cursor, _rows, _requested_rows), do: !!cursor

  defp row_to_cursor(nil), do: nil
  defp row_to_cursor({cursor_values, _record}), do: Pager.Cursor.encode(cursor_values)

  defp apply_where(query, _sort, :forward, nil, _config), do: query
  defp apply_where(query, _sort, :backward, nil, _config), do: query

  defp apply_where(query, sort, :forward, cursor, config) do
    config.queries.beyond_cursor(query, cursor, sort, :forward)
  end

  defp apply_where(query, sort, :backward, cursor, config) do
    config.queries.beyond_cursor(query, cursor, sort, :backward)
  end

  defp apply_order(query, sort, :forward, config) do
    config.queries.order(query, sort)
  end

  defp apply_order(query, sort, :backward, config) do
    query
    |> apply_order(sort, :forward, config)
    |> Ecto.Query.reverse_order()
  end

  defp apply_select(query, sort, config) do
    config.queries.with_cursor_fields(query, sort)
  end

  # TODO: enforce min/max limit
  defp apply_limit(query, limit, _config) do
    Ecto.Query.limit(query, ^limit)
  end
end
