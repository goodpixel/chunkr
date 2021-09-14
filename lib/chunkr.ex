defmodule Chunkr do
  require Ecto.Query
  alias Chunkr.{Config, Cursor, Opts, Page}

  defmacro __using__(config) do
    quote do
      @default_config Config.new([{:repo, __MODULE__} | unquote(config)])

      def paginate!(queryable, query_name, opts) do
        unquote(__MODULE__).paginate!(queryable, query_name, opts, @default_config)
      end

      def paginate(queryable, query_name, opts) do
        unquote(__MODULE__).paginate(queryable, query_name, opts, @default_config)
      end
    end
  end

  def paginate!(queryable, query_name, opts, config) do
    case paginate(queryable, query_name, opts, config) do
      {:ok, page} -> page
      {:error, message} -> raise ArgumentError, message
    end
  end

  def paginate(queryable, query_name, opts, %Config{} = config) do
    case Opts.new(queryable, query_name, opts) do
      {:ok, opts} ->
        rows =
          opts.query
          |> apply_where(opts, config)
          |> apply_order(opts.name, opts.paging_dir, config)
          |> apply_select(opts, config)
          |> apply_limit(opts.limit + 1, config)
          |> config.repo.all()

        requested_rows = Enum.take(rows, opts.limit)

        rows_to_return =
          case opts.paging_dir do
            :forward -> requested_rows
            :backward -> Enum.reverse(requested_rows)
          end

        {:ok,
         %Page{
           raw_results: rows_to_return,
           has_previous_page: has_previous?(opts, rows, requested_rows),
           has_next_page: has_next?(opts, rows, requested_rows),
           start_cursor: List.first(rows_to_return) |> row_to_cursor(),
           end_cursor: List.last(rows_to_return) |> row_to_cursor(),
           config: config,
           opts: opts
         }}

      {:invalid_opts, message} ->
        {:error, message}
    end
  end

  defp has_previous?(%{paging_dir: :forward} = opts, _, _), do: !!opts.cursor
  defp has_previous?(%{paging_dir: :backward}, rows, requested_rows), do: rows != requested_rows

  defp has_next?(%{paging_dir: :forward}, rows, requested_rows), do: rows != requested_rows
  defp has_next?(%{paging_dir: :backward} = opts, _, _), do: !!opts.cursor

  defp row_to_cursor(nil), do: nil
  defp row_to_cursor({cursor_values, _record}), do: Cursor.encode(cursor_values)

  defp apply_where(query, %{cursor: nil}, _config), do: query

  defp apply_where(query, opts, config) do
    cursor_values = Cursor.decode!(opts.cursor)
    config.queries.beyond_cursor(query, cursor_values, opts.name, opts.paging_dir)
  end

  defp apply_order(query, name, :forward, config) do
    config.queries.apply_order(query, name)
  end

  defp apply_order(query, name, :backward, config) do
    apply_order(query, name, :forward, config)
    |> Ecto.Query.reverse_order()
  end

  defp apply_select(query, opts, config) do
    config.queries.apply_select(query, opts.name)
  end

  # TODO: enforce min/max limit
  defp apply_limit(query, limit, _config) do
    Ecto.Query.limit(query, ^limit)
  end
end
