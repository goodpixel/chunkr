defmodule Chunkr.Page do
  @moduledoc """
  A single page of results.

  ## Fields

    * `raw_results` — rows in the form `{cursor_values, record}` where `cursor_values` is the list
      of values to be used for generating a cursor. Note that in cases where coalescing or other
      manipulation was performed for the sake of pagination, the cursor values will reflect
      that manipulation, while the record itself will by default not.
    * `has_previous_page` — whether or not there is a previous page of results.
    * `has_next_page` — whether or not there is a subsequent page of results.
    * `start_cursor` — a cursor representing the first record in this page of results.
    * `end_cursor` — a cursor representing the last record in this page of results.
    * `opts` — `Chunkr.Opts` used to generate this page of results.
  """

  alias Chunkr.{Cursor, Opts, Page}

  @type record :: any()

  @type t :: %__MODULE__{
          raw_results: [{Cursor.cursor_values(), record()}],
          has_previous_page: boolean(),
          has_next_page: boolean(),
          start_cursor: Cursor.opaque_cursor() | nil,
          end_cursor: Cursor.opaque_cursor() | nil,
          opts: Opts.t()
        }

  @enforce_keys [
    :raw_results,
    :has_previous_page,
    :has_next_page,
    :start_cursor,
    :end_cursor,
    :opts
  ]
  defstruct [
    :raw_results,
    :has_previous_page,
    :has_next_page,
    :start_cursor,
    :end_cursor,
    :opts
  ]

  @doc """
  Fetches the total, non-paginated count of records that match the query.

  Counting the total number of records requires an extra database query,
  so this is not performed by default.
  """
  @spec total_count(Page.t()) :: integer()
  def total_count(%__MODULE__{opts: opts}) do
    opts.repo.aggregate(opts.query, :count)
  end

  @doc """
  Extracts just the records out of the raw results.
  """
  @spec records(Page.t()) :: [any()]
  def records(%__MODULE__{} = page) do
    Enum.map(page.raw_results, fn {_cursor_values, record} -> record end)
  end

  @doc """
  Returns opaque cursors with their corresponding records.
  """
  @spec cursors_and_records(Page.t()) :: [{Cursor.opaque_cursor(), any()}]
  def cursors_and_records(%__MODULE__{} = page) do
    Enum.map(page.raw_results, fn {cursor_values, record} ->
      {Cursor.encode(cursor_values), record}
    end)
  end
end
