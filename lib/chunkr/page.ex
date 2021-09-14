defmodule Chunkr.Page do
  @moduledoc """
  A single page of results.

  ## Fields

    * `total_count` — not provided by default since it requires an extra database query, but
      available by calling `fetch_total_count`
    * `raw_results` — rows in the form `{cursor_values, record}` where `cursor_values` is the list
      of values to be used for generating a cursor. Note that in cases where coalescing or other
      manipulation was performed for the sake of pagination, the cursor values will reflect
      that manipulation, while the record itself will by default not.
    * `has_previous_page` — whether or not there is a previous page of results.
    * `has_next_page` — whether or not there is a subsequent page of results.
    * `start_cursor` — a cursor representing the first record in this page of results.
    * `end_cursor` — a cursor representing the last record in this page of results.
    * `config` — config used to generate this page.
  """

  @type cursor_values :: [any()]
  @type record :: any()

  @type t :: %__MODULE__{
          raw_results: [{cursor_values(), record()}],
          has_previous_page: boolean(),
          has_next_page: boolean(),
          start_cursor: Chunkr.Cursor.opaque_cursor() | nil,
          end_cursor: Chunkr.Cursor.opaque_cursor() | nil,
          config: Chunkr.Config.t(),
          opts: Chunkr.Opts.t()
        }

  @enforce_keys [
    :raw_results,
    :has_previous_page,
    :has_next_page,
    :start_cursor,
    :end_cursor,
    :config,
    :opts
  ]
  defstruct [
    :raw_results,
    :has_previous_page,
    :has_next_page,
    :start_cursor,
    :end_cursor,
    :config,
    :opts
  ]
end