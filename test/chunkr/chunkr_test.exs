defmodule ChunkrTest do
  use ExUnit.Case, async: true
  import Ecto.Query
  import Chunkr.PaginationHelpers
  import Chunkr.TestDataGenerators

  alias Chunkr.{PhoneNumber, TestRepo, User}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chunkr.TestRepo)
  end

  @count 30

  test "paginating by a single field" do
    {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
    query = from(u in User, as: :user)
    expected_results = TestRepo.all(from(u in User, order_by: [asc: u.id]))
    verify_pagination(TestRepo, query, :single_field, :asc, expected_results, @count)
  end

  test "inverting a single field sort" do
    {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
    query = from(u in User, as: :user)
    expected_results = TestRepo.all(from(u in User, order_by: [desc: u.id]))
    verify_pagination(TestRepo, query, :single_field, :desc, expected_results, @count)
  end

  test "paginating by two fields" do
    {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
    query = from(u in User, as: :user)
    expected = TestRepo.all(from u in User, order_by: [asc_nulls_last: u.last_name, desc: u.id])
    verify_pagination(TestRepo, query, :two_fields, :asc, expected, @count)
  end

  test "inverting a two field sort" do
    {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
    query = from(u in User, as: :user)
    expected = TestRepo.all(from u in User, order_by: [desc_nulls_first: u.last_name, asc: u.id])
    verify_pagination(TestRepo, query, :two_fields, :desc, expected, @count)
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

    verify_pagination(TestRepo, query, :three_fields, :asc, expected_results, @count)
  end

  test "inverting a three field sort" do
    {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
    query = from(u in User, as: :user)

    expected_results =
      TestRepo.all(
        from(u in User,
          order_by: [
            desc_nulls_first: u.last_name,
            desc_nulls_first: u.first_name,
            asc: u.id
          ]
        )
      )

    verify_pagination(TestRepo, query, :three_fields, :desc, expected_results, @count)
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

    verify_pagination(TestRepo, query, :four_fields, :desc, expected_results, @count)
  end

  test "inverting a four field sort" do
    {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
    query = from(u in User, as: :user)

    expected_results =
      TestRepo.all(
        from(u in User,
          order_by: [
            asc_nulls_last: u.last_name,
            asc_nulls_last: u.first_name,
            asc_nulls_last: u.middle_name,
            desc: u.id
          ]
        )
      )

    verify_pagination(TestRepo, query, :four_fields, :asc, expected_results, @count)
  end

  test "paginating by UUID" do
    {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
    query = from(u in User, as: :user)

    expected_results =
      TestRepo.all(from u in User, order_by: [asc_nulls_last: u.last_name, desc: u.public_id])

    verify_pagination(TestRepo, query, :uuid, :asc, expected_results, @count)
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

    verify_pagination(TestRepo, query, :subquery, :desc, expected_results, expected_count)
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

    verify_pagination(TestRepo, query, :computed_value, :desc, expected_results, @count)
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

    verify_pagination(
      TestRepo,
      query,
      :by_possibly_null_association,
      :asc,
      expected_results,
      @count
    )
  end

  #
  # HELPERS
  #
  defp maybe_assign_user_ids(attrs, [] = _user_ids), do: attrs

  defp maybe_assign_user_ids(attrs, user_ids) when length(user_ids) > 0 do
    for {attrs, index} <- Enum.with_index(attrs) do
      if Integer.mod(index, 2) == 0 do
        Map.put(attrs, :user_id, Enum.random(user_ids))
      else
        attrs
      end
    end
  end
end
