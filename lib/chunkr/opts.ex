defmodule Chunkr.Opts do
  @moduledoc """
  Options for paginating

  ## Fields

    * `:query` — The non-paginated query to be extended for pagination purposes.
    * `:name` — The name of the pagination strategy.
    * `:cursor` — The cursor beyond which results are retrieved.
    * `:paging_dir` — Either `:forward` or `:backward` depending on whether we're paging from the
      start of the result set toward the end or from the end of the result set toward the beginning.
    * `:max_limit` — The maximum number of results the user can request per page.
    * `:limit` — The number of results to actually query for this page. Must be between `0` and
      `max_limit`.
  """
  @type t :: %__MODULE__{
          repo: atom(),
          queries: atom(),
          query: Ecto.Query.t(),
          name: atom(),
          cursor: Chunkr.Cursor.opaque_cursor() | nil,
          paging_dir: :forward | :backward,
          max_limit: pos_integer(),
          limit: pos_integer()
        }

  # @enforce_keys [:repo, :queries]
  defstruct [:repo, :queries, :query, :name, :cursor, :paging_dir, :max_limit, :limit]

  def new(query, query_name, opts) do
    case validate_options(query_name, opts) do
      {:ok, opts} -> {:ok, struct!(%__MODULE__{query: query}, opts)}
      {:error, message} -> {:invalid_opts, message}
    end
  end

  defp validate_options(query_name, opts) do
    with {:ok, limit, cursor, paging_direction} <- validate(opts),
         {:ok, _limit} <- validate_limit(limit, opts) do
      {:ok,
       %{
         repo: Keyword.fetch!(opts, :repo),
         queries: Keyword.fetch!(opts, :queries),
         name: query_name,
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
