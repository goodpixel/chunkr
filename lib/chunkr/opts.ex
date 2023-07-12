defmodule Chunkr.Opts do
  @moduledoc """
  Options for paginating.

  ## Fields

    * `:repo` — The `Ecto.Repo` for the query.
    * `:planner` — The module implementing the pagination strategy.
    * `:strategy` — The name of the pagination strategy to use.
    * `:disposition` — Whether the strategy should be executed as written or inverted.
      For example, if the established strategy orders by `[desc: :last_name, asc: :created_at]`,
      inverting would flip the ordering to be `[asc: :last_name, desc: :created_at]`.
      Must be either `:regular` or `:inverted`.
    * `:paging_dir` — Either `:forward` or `:backward` depending on whether gathering
      results from the start or the end of the result set (i.e. whether the limit was
      specified as `:first` or `:last`).
    * `:cursor` — The `:after` or `:before` cursor beyond which results are retrieved.
    * `:cursor_mod` — The module implementing the `Chunkr.Cursor` behaviour to be used
      for encoding/decoding cursor values. The default is `Chunkr.Cursor.Base64`, but a
      custom cursor module can be provided.
    * `:max_limit` — The maximum allowed page size.
    * `:limit` — The requested page size (as specified by `:first` or `:last`).
  """

  @type t :: %__MODULE__{
          repo: atom(),
          planner: atom(),
          strategy: atom(),
          disposition: :regular | :inverted,
          paging_dir: :forward | :backward,
          cursor: Chunkr.Cursor.cursor() | nil,
          cursor_mod: module(),
          max_limit: pos_integer(),
          limit: pos_integer()
        }

  defstruct [
    :repo,
    :planner,
    :strategy,
    :disposition,
    :paging_dir,
    :cursor,
    :cursor_mod,
    :max_limit,
    :limit
  ]

  @doc """
  Validate provided options and return a `Chunkr.Opts` struct
  """
  @spec new(keyword) :: {:invalid_opts, String.t()} | {:ok, struct}
  def new(opts) do
    case validate_options(opts) do
      {:ok, opts} -> {:ok, struct!(__MODULE__, opts)}
      {:error, message} -> {:invalid_opts, message}
    end
  end

  defp validate_options(opts) do
    with {:ok, limit, cursor, disposition, paging_direction} <- validate(opts),
         {:ok, _limit} <- validate_limit(limit, opts) do
      {:ok,
       %{
         repo: Keyword.fetch!(opts, :repo),
         planner: Keyword.fetch!(opts, :planner),
         strategy: Keyword.fetch!(opts, :by),
         paging_dir: paging_direction,
         disposition: disposition,
         max_limit: Keyword.fetch!(opts, :max_limit),
         limit: limit,
         cursor: cursor,
         cursor_mod: Keyword.fetch!(opts, :cursor_mod)
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
                |> Enum.map_join(" | ", &"[#{&1}]")

  defp validate(opts) do
    provided_keys = opts |> Keyword.take([:first, :last, :after, :before]) |> Keyword.keys()
    provided_key_set = MapSet.new(provided_keys)

    case MapSet.new(@valid_sets) |> MapSet.member?(provided_key_set) do
      true ->
        {:ok, get_limit(opts), get_cursor(opts), get_disposition(opts), get_paging_dir(opts)}

      false ->
        {:error, pagination_args_error(provided_keys)}
    end
  end

  defp get_limit(opts) do
    Keyword.get(opts, :first) || Keyword.get(opts, :last)
  end

  defp get_cursor(opts) do
    Keyword.get(opts, :after) || Keyword.get(opts, :before)
  end

  defp get_disposition(opts) do
    if Keyword.get(opts, :inverted) == true, do: :inverted, else: :regular
  end

  defp get_paging_dir(opts) do
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
