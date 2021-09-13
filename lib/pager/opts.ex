defmodule Pager.Opts do
  @moduledoc """
  Options for paginating

  ## Fields

    * `query` — the non-paginated query to be extended for pagination purposes.
    * `sort` — the custom sort used.
    * `cursor` — the cursor beyond which results are retrieved.
    * `paging_dir` — either `:forward` or `:backward` depending on whether we're paging from the
      start of the result set toward the end or from the end of the result set toward the beginning.
    * `limit` — the maximum number of results being retrieved from the page.
  """

  @type t :: %__MODULE__{
          query: Ecto.Query.t(),
          sort: atom(),
          cursor: Pager.Cursor.opaque_cursor() | nil,
          paging_dir: :forward | :backward,
          limit: pos_integer()
        }

  defstruct [:query, :sort, :cursor, :paging_dir, :limit]

  def new(query, sort, opts) do
    with {:ok, opts} <- validate_options(sort, opts) do
      {:ok, struct!(%__MODULE__{query: query}, opts)}
    else
      {:error, message} -> {:invalid_opts, message}
    end
  end

  defp validate_options(sort_name, opts) do
    with {:ok, limit, cursor, paging_direction} <- validate(opts) do
      {:ok,
       %{
         sort: sort_name,
         paging_dir: paging_direction,
         limit: limit,
         cursor: cursor
       }}
    end
  end

  @valid_keys [
    [:first],
    [:first, :after],
    [:last],
    [:last, :before]
  ]

  @valid_sets Enum.map(@valid_keys, &MapSet.new/1)

  @valid_combos @valid_keys
                |> Enum.map(&Enum.join(&1, ", "))
                |> Enum.map(&"[#{&1}]")
                |> Enum.join(" | ")

  defp validate(opts) do
    provided_keys = opts |> Keyword.take([:first, :last, :after, :before]) |> Keyword.keys()
    provided_set = MapSet.new(provided_keys)

    case MapSet.new(@valid_sets) |> MapSet.member?(provided_set) do
      true -> {:ok, get_limit(opts), get_cursor(opts), get_paging_direction(opts)}
      false -> {:error, pagination_args_error(provided_keys)}
    end
  end

  defp get_limit(opts) do
    Keyword.get(opts, :first) || Keyword.get(opts, :last)
  end

  defp get_cursor(opts) do
    Keyword.get(opts, :after) || Keyword.get(opts, :before)
  end

  defp get_paging_direction(opts) do
    if Keyword.get(opts, :first), do: :forward, else: :backward
  end

  defp pagination_args_error(provided_keys) do
    ~s(Invalid pagination params: [#{Enum.join(provided_keys, ", ")}]. Valid combinations are: #{@valid_combos})
  end
end