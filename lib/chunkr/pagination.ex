defmodule Chunkr.Pagination do
  @moduledoc """
  Pagination functions.

  This module provides the high-level pagination logic. Under the hood, it delegates to whatever
  "planner" module is configured in the call to `use Chunkr, planner: YourApp.PaginationPlanner`.

  Note that you'll generally want to call the `paginate/3` or `paginate!/3` convenience
  functions on your Repo module and not the ones directly provided by this module. That way,
  you'll inherit any configuration previously set on your call to `use Chunkr`.
  """

  require Ecto.Query
  alias Chunkr.{Cursor, Opts, Page}

  @doc """
  Paginates a query using a predefined strategy.

  The query _must not_ be ordered before calling `paginate/3` as the proper ordering will be
  automatically applied per the registered strategy.

  ## Options

    * `:by` — The named pagination strategy to use.
    * `:inverted` — Whether the strategy should be executed as written or inverted.
      For example, if the established strategy orders by `[desc: :last_name, asc: :created_at]`,
      inverting would flip the ordering to be `[asc: :last_name, desc: :created_at]`. Inverts
      the specified ordering only if set to `true`.
    * `:first` — Retrieve the first _n_ results; must be between `0` and `:max_page_size`.
    * `:last` — Retrieve the last _n_ results; must be between `0` and `:max_page_size`.
    * `:after` — Return results starting after the provided cursor; optionally pairs with `:first`.
    * `:before` — Return results ending at the provided cursor; optionally pairs with `:last`.
    * `:max_page_size` — Maximum number of results the user can request for this query.
      Default is #{Chunkr.default_max_page_size()}.
    * `:cursor_mod` — Specifies the cursor module to use for encoding values as a cursor.
      Defaults to `Chunkr.Cursor.Base64`.
    * `:repo` — Repo to use for querying (automatically passed when calling either of
      the paginate convenience functions on your Repo).
    * `:planner` — The module implementing your pagination strategy (automatically passed
      when calling either of the paginate convenience functions on your Repo).
  """
  @spec paginate(any, keyword) :: {:error, String.t()} | {:ok, Page.t()}
  def paginate(queryable, options) do
    with {:ok, opts} <- Opts.new(options),
         {:ok, queryable} <- validate_queryable(queryable) do
      extended_rows =
        queryable
        |> apply_where(opts)
        |> apply_order(opts)
        |> apply_select(opts)
        |> apply_limit(opts)
        |> opts.repo.all()

      requested_rows = Enum.take(extended_rows, opts.page_size)

      rows_to_return =
        case opts.paging_dir do
          :forward -> requested_rows
          :backward -> Enum.reverse(requested_rows)
        end

      {:ok,
       %Page{
         raw_results: rows_to_return,
         has_previous_page: has_previous_page?(opts, extended_rows, requested_rows),
         has_next_page: has_next_page?(opts, extended_rows, requested_rows),
         start_cursor: List.first(rows_to_return) |> row_to_cursor(opts),
         end_cursor: List.last(rows_to_return) |> row_to_cursor(opts),
         opts: opts
       }}
    else
      {:invalid_opts, message} ->
        {:error, message}

      {:invalid_query, :already_ordered} ->
        {:error, "Query must not be ordered prior to paginating with Chunkr"}
    end
  end

  defp validate_queryable(%Ecto.Query{order_bys: [_ | _]}), do: {:invalid_query, :already_ordered}
  defp validate_queryable(query), do: {:ok, query}

  @doc """
  Same as `paginate/3`, but raises an error for invalid input.
  """
  @spec paginate!(any, keyword) :: Page.t()
  def paginate!(queryable, opts) do
    case paginate(queryable, opts) do
      {:ok, page} -> page
      {:error, message} -> raise ArgumentError, message
    end
  end

  defp has_previous_page?(%{paging_dir: :forward} = opts, _, _), do: !!opts.cursor

  defp has_previous_page?(%{paging_dir: :backward}, rows, requested_rows),
    do: rows != requested_rows

  defp has_next_page?(%{paging_dir: :forward}, rows, requested_rows), do: rows != requested_rows
  defp has_next_page?(%{paging_dir: :backward} = opts, _, _), do: !!opts.cursor

  defp row_to_cursor(nil, _opts), do: nil
  defp row_to_cursor({cursor_values, _}, opts), do: Cursor.encode!(cursor_values, opts.cursor_mod)

  defp apply_where(query, %{cursor: nil}), do: query

  defp apply_where(query, opts) do
    cursor_values = Cursor.decode!(opts.cursor, opts.cursor_mod)

    opts.planner.beyond_cursor(
      query,
      opts.strategy,
      opts.disposition,
      opts.paging_dir,
      cursor_values
    )
  end

  defp apply_order(query, opts) do
    opts.planner.apply_order(query, opts.strategy, opts.disposition, opts.paging_dir)
  end

  defp apply_select(query, opts) do
    opts.planner.apply_select(query, opts.strategy)
  end

  defp apply_limit(query, opts) do
    limit = opts.page_size + 1
    Ecto.Query.limit(query, ^limit)
  end
end
