defmodule Chunkr do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  require Ecto.Query
  alias Chunkr.{Cursor, Opts, Page}

  @default_max_limit 100

  @doc false
  defmacro __using__(opts) do
    quote do
      @default_opts unquote(opts) ++ [{:repo, __MODULE__}, {:max_limit, 100}]

      def paginate!(queryable, strategy, sort_dir, opts) do
        unquote(__MODULE__).paginate!(queryable, strategy, sort_dir, opts ++ @default_opts)
      end

      def paginate(queryable, strategy, sort_dir, opts) do
        unquote(__MODULE__).paginate(queryable, strategy, sort_dir, opts ++ @default_opts)
      end
    end
  end

  @doc """
  Same as `paginate/3`, but raises an error for invalid input.
  """
  def paginate!(queryable, strategy, sort_dir, opts) do
    case paginate(queryable, strategy, sort_dir, opts) do
      {:ok, page} -> page
      {:error, message} -> raise ArgumentError, message
    end
  end

  @doc """
  Paginates an `Ecto.Queryable`.

  Extends the provided `Ecto.Queryable` with the necessary filtering, ordering, and cursor field
  selection for the sake of pagination, then executes the query and returns a `Chunkr.Page` or
  results.

  ## Options

    * `:max_limit` — The maximum number or results the user can request for this query.
      The default is #{@default_max_limit}.
    * `:first` — Retrieve the first _n_ results; must be between `0` and `:max_limit`.
    * `:last` — Retrieve the last _n_ results; must be between `0` and `:max_limit`.
    * `:after` — Return results starting after the provided cursor; optionally pairs with `:first`.
    * `:before` — Return results ending at the provided cursor; optionally pairs with `:last`.
  """
  def paginate(queryable, strategy, sort_dir, options) do
    case Opts.new(queryable, strategy, sort_dir, options) do
      {:ok, opts} ->
        extended_rows =
          queryable
          |> apply_where(opts)
          |> apply_order(opts)
          |> apply_select(opts)
          |> apply_limit(opts.limit + 1)
          |> opts.repo.all()

        requested_rows = Enum.take(extended_rows, opts.limit)

        rows_to_return =
          case opts.paging_dir do
            :forward -> requested_rows
            :backward -> Enum.reverse(requested_rows)
          end

        {:ok,
         %Page{
           raw_results: rows_to_return,
           has_previous_page: has_previous?(opts, extended_rows, requested_rows),
           has_next_page: has_next?(opts, extended_rows, requested_rows),
           start_cursor: List.first(rows_to_return) |> row_to_cursor(),
           end_cursor: List.last(rows_to_return) |> row_to_cursor(),
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

  defp apply_where(query, %{cursor: nil}), do: query

  defp apply_where(query, opts) do
    cursor_values = Cursor.decode!(opts.cursor)

    opts.planner.beyond_cursor(
      query,
      opts.strategy,
      opts.sort_dir,
      opts.paging_dir,
      cursor_values
    )
  end

  defp apply_order(query, opts) do
    opts.planner.apply_order(query, opts.strategy, opts.sort_dir, opts.paging_dir)
  end

  defp apply_select(query, opts) do
    opts.planner.apply_select(query, opts.strategy)
  end

  # TODO: Move this
  defp apply_limit(query, limit) do
    Ecto.Query.limit(query, ^limit)
  end
end
