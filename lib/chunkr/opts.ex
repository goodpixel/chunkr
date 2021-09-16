defmodule Chunkr.Opts do
  @moduledoc """
  Options for paginating

  ## Fields

    * `:repo` — The `Ecto.Repo` for the query.
    * `:planner` — The module implementing the pagination strategy.
    * `:query` — The non-paginated query to be extended for pagination purposes.
    * `:strategy` — The name of the pagination strategy to use.
    * `:sort_dir` — The primary sort direction used for the query. Note that this
      aligns with the very first `sort` clause registered in the named pagination strategy.
      Any subsequent sort directions within the strategy will always be automatically
      adjusted to maintain the overall strategy.
    * `:paging_dir` — Either `:forward` or `:backward` depending on whether gathering
      results from the start or the end of the result set (i.e. whether the limit was
      specified as `:first` or `:last`).
    * `:cursor` — The `:after` or `:before` cursor beyond which results are retrieved.
    * `:max_limit` — The maximum allowed page size.
    * `:limit` — The requested page size (as specified by `:first` or `:last`).
  """

  @type sort_dir :: :asc | :desc

  @type t :: %__MODULE__{
          repo: atom(),
          planner: atom(),
          query: Ecto.Query.t(),
          strategy: atom(),
          sort_dir: sort_dir(),
          paging_dir: :forward | :backward,
          cursor: Chunkr.Cursor.opaque_cursor() | nil,
          max_limit: pos_integer(),
          limit: pos_integer()
        }

  defstruct [
    :repo,
    :planner,
    :query,
    :strategy,
    :sort_dir,
    :paging_dir,
    :cursor,
    :max_limit,
    :limit
  ]

  def new(query, strategy, sort_dir, opts) do
    case validate_options(strategy, opts) do
      {:ok, opts} -> {:ok, struct!(%__MODULE__{query: query, sort_dir: sort_dir}, opts)}
      {:error, message} -> {:invalid_opts, message}
    end
  end

  defp validate_options(strategy, opts) do
    with {:ok, limit, cursor, paging_direction} <- validate(opts),
         {:ok, _limit} <- validate_limit(limit, opts) do
      {:ok,
       %{
         repo: Keyword.fetch!(opts, :repo),
         planner: Keyword.fetch!(opts, :planner),
         strategy: strategy,
         paging_dir: paging_direction,
         max_limit: Keyword.fetch!(opts, :max_limit),
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
    provided_key_set = MapSet.new(provided_keys)

    case MapSet.new(@valid_sets) |> MapSet.member?(provided_key_set) do
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
    ~s(Invalid pagination params: [#{Enum.join(provided_keys, ", ")}]. Valid combinations are: #{@valid_combos}.)
  end

  defp validate_limit(limit, opts) do
    max_limit = Keyword.fetch!(opts, :max_limit)

    cond do
      limit < 0 ->
        {:error, "Page size of #{limit} was requested, but page size must be at least 0."}

      limit <= max_limit ->
        {:ok, limit}

      true ->
        {:error, "Page size of #{limit} was requested, but maximum page size is #{max_limit}."}
    end
  end
end
