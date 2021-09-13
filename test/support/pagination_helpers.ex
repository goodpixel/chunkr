defmodule Pager.PaginationHelpers do
  use ExUnitProperties

  alias Pager.Page

  @doc """
  Streams pages for the entire result set starting with the given opts
  """
  def page_thru(repo, query, sort, opts) do
    dir =
      case opts do
        [first: _limit] -> :forward
        [last: _limit] -> :backward
      end

    repo.paginate!(query, sort, opts)
    |> Stream.unfold(fn
      %Page{has_next_page: true, end_cursor: c} = page when dir == :forward ->
        opts = Keyword.put(opts, :after, c)
        next_result = repo.paginate!(query, sort, opts)
        {page, next_result}

      %Page{has_next_page: false} = page when dir == :forward ->
        {page, :done}

      %Page{has_previous_page: true, start_cursor: c} = page when dir == :backward ->
        opts = Keyword.put(opts, :before, c)
        next_result = repo.paginate!(query, sort, opts)
        {page, next_result}

      %Page{has_previous_page: false} = page when dir == :backward ->
        {page, :done}

      :done ->
        nil
    end)
  end

  def user_attrs() do
    gen all(
          public_id <- uuid(),
          first_name <- one_of([constant(nil), string(:ascii)]),
          middle_name <- one_of([constant(nil), string(:ascii)]),
          last_name <- one_of([constant(nil), string(:ascii)]),
          inserted_at <- datetime(),
          updated_at <- datetime()
        ) do
      %{
        public_id: public_id,
        first_name: first_name,
        middle_name: middle_name,
        last_name: last_name,
        inserted_at: inserted_at,
        updated_at: updated_at
      }
    end
  end

  defp uuid() do
    StreamData.map(StreamData.constant(nil), fn _ -> Ecto.UUID.generate() end)
  end

  def phone_attrs() do
    gen all(
          number <- phone_number(),
          inserted_at <- datetime(),
          updated_at <- datetime()
        ) do
      %{
        number: number,
        inserted_at: inserted_at,
        updated_at: updated_at
      }
    end
  end

  defp phone_number() do
    gen all(
          digits <- list_of(integer(0..9), min_length: 7, max_length: 13),
          punctuation <- list_of(punctuation(), max_length: 6)
        ) do
      digits
      |> Enum.concat(punctuation)
      |> Enum.shuffle()
      |> Enum.join()
    end
  end

  defp punctuation() do
    one_of([constant("."), constant("-"), constant("("), constant(")"), constant(" ")])
  end

  @microseconds_per_year 365 * 24 * 60 * 60 * 1000 * 1000

  # generates a date between 1,000 years ago and 1,000 years from now
  defp datetime() do
    now = DateTime.utc_now()

    earliest =
      DateTime.add(now, -1_000 * @microseconds_per_year, :microsecond)
      |> DateTime.to_unix(:microsecond)

    latest =
      DateTime.add(now, 1_000 * @microseconds_per_year, :microsecond)
      |> DateTime.to_unix(:microsecond)

    gen all(int <- integer(earliest..latest)) do
      DateTime.from_unix!(int, :microsecond)
    end
  end

  def maybe_assign_user_ids(attrs, [] = _user_ids), do: attrs

  def maybe_assign_user_ids(attrs, user_ids) when length(user_ids) > 0 do
    for {attrs, index} <- Enum.with_index(attrs) do
      if Integer.mod(index, 2) == 0 do
        Map.put(attrs, :user_id, Enum.random(user_ids))
      else
        attrs
      end
    end
  end
end
