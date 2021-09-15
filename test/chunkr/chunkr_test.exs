defmodule ChunkrTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import Ecto.Query
  import Chunkr.PaginationHelpers

  doctest Chunkr

  alias Chunkr.{PhoneNumber, TestRepo, User}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chunkr.TestRepo)
  end

  @count 30

  test "paginating by a single field" do
    {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
    query = from(u in User, as: :user)
    expected_results = TestRepo.all(from(u in User, order_by: [asc: u.id]))
    verify_pagination(TestRepo, query, :single_field, expected_results, @count)
  end

  test "paginating by two fields" do
    {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
    query = from(u in User, as: :user)
    expected = TestRepo.all(from u in User, order_by: [asc_nulls_last: u.last_name, desc: u.id])
    verify_pagination(TestRepo, query, :two_fields, expected, @count)
  end

  test "paginating by three fields" do
    {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
    query = from(u in User, as: :user)

    expected_results =
      TestRepo.all(
        from(u in User,
          order_by: [
            asc_nulls_last: u.last_name,
            asc_nulls_last: u.first_name,
            desc: u.id
          ]
        )
      )

    verify_pagination(TestRepo, query, :three_fields, expected_results, @count)
  end

  test "paginating by four fields" do
    {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
    query = from(u in User, as: :user)

    expected_results =
      TestRepo.all(
        from(u in User,
          order_by: [
            desc_nulls_first: u.last_name,
            desc_nulls_first: u.first_name,
            desc_nulls_first: u.middle_name,
            asc: u.id
          ]
        )
      )

    verify_pagination(TestRepo, query, :four_fields, expected_results, @count)
  end

  test "paginating by UUID" do
    {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
    query = from(u in User, as: :user)

    expected_results =
      TestRepo.all(from u in User, order_by: [asc_nulls_last: u.last_name, desc: u.public_id])

    verify_pagination(TestRepo, query, :uuid, expected_results, @count)
  end

  test "paginating with a subquery" do
    TestRepo.insert_all(User, Enum.take(user_attrs(), @count))

    query =
      from(u in User,
        as: :user,
        join: sub in subquery(from u in User, where: not is_nil(u.last_name)),
        on: sub.id == u.id
      )

    expected_count = TestRepo.aggregate(from(u in User, where: not is_nil(u.last_name)), :count)
    expected_results = TestRepo.all(from u in query, order_by: [desc: u.last_name, asc: u.id])

    verify_pagination(TestRepo, query, :subquery, expected_results, expected_count)
  end

  test "sorting via a computed value" do
    TestRepo.insert_all(User, Enum.take(user_attrs(), @count))

    query =
      from u in User,
        as: :user,
        join:
          interesting_facts in subquery(
            from sub in User,
              select: %{
                user_id: sub.id,
                length_of_name: fragment("coalesce(length(?), ?)", sub.first_name, 0)
              }
          ),
        on: interesting_facts.user_id == u.id,
        as: :user_data

    expected_results =
      TestRepo.all(
        from u in query,
          order_by: [
            desc: fragment("coalesce(length(?), ?)", u.first_name, 0),
            asc: u.id
          ]
      )

    verify_pagination(TestRepo, query, :computed_value, expected_results, @count)
  end

  test "sorting by a potentially-missing association" do
    user_attrs = Enum.take(user_attrs(), @count)
    {_, users} = TestRepo.insert_all(User, user_attrs, returning: true)
    user_ids = users |> Enum.map(& &1.id)

    phone_attrs = Enum.take(phone_attrs(), @count)
    phone_attrs = maybe_assign_user_ids(phone_attrs, user_ids)
    TestRepo.insert_all(PhoneNumber, phone_attrs)

    query =
      from p in PhoneNumber,
        as: :phone,
        left_join: u in assoc(p, :user),
        as: :user,
        preload: [user: u]

    expected_results =
      TestRepo.all(
        from p in PhoneNumber,
          left_join: u in assoc(p, :user),
          order_by: [
            asc_nulls_last: u.first_name,
            asc: p.id
          ],
          preload: [user: u]
      )

    verify_pagination(TestRepo, query, :by_possibly_null_association, expected_results, @count)
  end

  # TEST DATA GENERATORS

  defp user_attrs() do
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
