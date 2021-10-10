defmodule Chunkr.Pagination do
  @moduledoc """
  Generic pagination functions.

  This module provides generic pagination functions that are not specific to Ecto.
  Under the hood, they delegate to whatever `:planner` is configured in the call to
  `use Chunkr, planner: YourApp.PaginationPlanner`.

  The expected usage is that the module referenced by the `:planner` opt will itself
  `use Chunkr.PaginationPlanner`, which provides macros to automically implement the
  functions necessary to extend your original query with Ecto-based filtering, sorting,
  limiting, and field selection.

  Note that you'll generally want to call the `paginate/4` or `paginate!/4` convenience
  functions on your Repo module and not directly on this module. That way, you'll
  automatically inherit any configuration provided in your call to `use Chunkr`.
  """

  alias Chunkr.{Cursor, Opts, Page}

  @doc """
  Paginates a query in `sort_dir` using your predefined `strategy`.

  The `sort_dir` you specify aligns with the primary sort direction of your pagination strategy.
  However, you can also provide the inverse sort direction from what your pagination strategy
  specifies, and the entire sort strategy will automically be inverted.

  The query _must not_ be ordered before calling `paginate/4` as the proper ordering will be
  automatically applied per the registered strategy.

  ## Options

    * `:first` — Retrieve the first _n_ results; must be between `0` and `:max_limit`.
    * `:last` — Retrieve the last _n_ results; must be between `0` and `:max_limit`.
    * `:after` — Return results starting after the provided cursor; optionally pairs with `:first`.
    * `:before` — Return results ending at the provided cursor; optionally pairs with `:last`.
    * `:max_limit` — Maximum number of results the user can request for this query.
      Default is #{Chunkr.default_max_limit()}.
    * `:repo` — Repo to use for querying (automatically passed when calling either of
      the paginate convenience functions on your Repo).
    * `:planner` — The module implementing your pagination strategy (automatically passed
      when calling either of the paginate convenience functions on your Repo).
  """
  @spec paginate(any, atom(), Opts.sort_dir(), keyword) ::
          {:error, String.t()} | {:ok, Page.t()}
  def paginate(queryable, strategy, sort_dir, options) do
    with {:ok, opts} <- Opts.new(queryable, strategy, sort_dir, options),
         {:ok, queryable} <- validate_queryable(queryable) do
      extended_rows =
        queryable
        |> apply_where(opts)
        |> apply_order(opts)
        |> apply_select(opts)
        |> apply_limit(opts.limit + 1, opts)
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
         has_previous_page: has_previous_page?(opts, extended_rows, requested_rows),
         has_next_page: has_next_page?(opts, extended_rows, requested_rows),
         start_cursor: List.first(rows_to_return) |> row_to_cursor(),
         end_cursor: List.last(rows_to_return) |> row_to_cursor(),
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
  Same as `paginate/4`, but raises an error for invalid input.
  """
  @spec paginate!(any, atom(), Opts.sort_dir(), keyword) :: Page.t()
  def paginate!(queryable, strategy, sort_dir, opts) do
    case paginate(queryable, strategy, sort_dir, opts) do
      {:ok, page} -> page
      {:error, message} -> raise ArgumentError, message
    end
  end

  defp has_previous_page?(%{paging_dir: :forward} = opts, _, _), do: !!opts.cursor

  defp has_previous_page?(%{paging_dir: :backward}, rows, requested_rows),
    do: rows != requested_rows

  defp has_next_page?(%{paging_dir: :forward}, rows, requested_rows), do: rows != requested_rows
  defp has_next_page?(%{paging_dir: :backward} = opts, _, _), do: !!opts.cursor

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

  defp apply_limit(query, limit, opts) do
    opts.planner.apply_limit(query, limit)
  end
end
