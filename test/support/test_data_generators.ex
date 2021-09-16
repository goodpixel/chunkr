defmodule TestDataGenerators do
  @moduledoc false
  use ExUnitProperties

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

  def phone_number() do
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
  def datetime() do
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
end
