defmodule ChunkrTest do
  use ExUnit.Case, async: false
  import Ecto.Query
  import Chunkr.PaginationHelpers
  import Chunkr.TestDataGenerators

  alias Chunkr.{PhoneNumber, TestRepo, User}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Chunkr.TestRepo)
  end

  @count 30

  defp generate_users(count \\ @count) do
    {^count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), count))
  end

  test "paginating by a single field" do
    generate_users()
    query = from(u in User, as: :user)
    expected_results = TestRepo.all(from(u in User, order_by: [asc: u.id]))
    verify_pagination(TestRepo, query, :single_field, :asc, expected_results, @count)
  end

  test "inverting a single field sort" do
    generate_users()
    query = from(u in User, as: :user)
    expected_results = TestRepo.all(from(u in User, order_by: [desc: u.id]))
    verify_pagination(TestRepo, query, :single_field, :desc, expected_results, @count)
  end

  test "paginating by two fields" do
    # generate_users()
    params = [
      %{
        updated_at: ~U[1506-07-12 09:51:32.000000Z],
        inserted_at: ~U[1038-12-03 17:10:10.000000Z],
        last_name: "",
        middle_name: nil,
        first_name: nil,
        public_id: "d1728d8a-34b6-46f9-b57a-137fe40b5266",
        id: 12,
      },
      %{
        updated_at: ~U[1148-05-22 06:55:26.000000Z],
        inserted_at: ~U[2299-03-18 05:02:19.000000Z],
        last_name: "{",
        middle_name: "",
        first_name: "B",
        public_id: "7c0defad-ed6a-47f2-ad71-9d7fab0113f8",
        id: 1,
      },
      %{
        updated_at: ~U[2789-10-10 18:44:47.000000Z],
        inserted_at: ~U[1181-02-24 13:36:53.000000Z],
        last_name: nil,
        middle_name: "z;,SO(K@ew6_l<t'_,s#^16",
        first_name: "QMC)[WRO\\5^tX)]",
        public_id: "5560f8e6-41d5-4002-8929-04304a1efe0d",
        id: 30,
      },
      %{
        updated_at: ~U[2366-03-02 00:46:32.000000Z],
        inserted_at: ~U[2844-06-01 03:33:04.000000Z],
        last_name: "0D*",
        middle_name: nil,
        first_name: nil,
        public_id: "1c3a20ec-8b11-4b8b-8463-2a903453fb10",
        id: 22,
      }
    ]

    TestRepo.insert_all(User, params)

    query = from(u in User, as: :user)
    expected = TestRepo.all(from u in User, order_by: [asc_nulls_last: u.last_name, desc: u.id])

    expected
    |> Enum.map(&(&1.last_name))
    |> IO.inspect(label: "expected")
    verify_pagination(TestRepo, query, :two_fields, :asc, expected, 4)
  end

  # test "inverting a two field sort" do
  #   {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
  #   query = from(u in User, as: :user)
  #   expected = TestRepo.all(from u in User, order_by: [desc_nulls_first: u.last_name, asc: u.id])
  #   verify_pagination(TestRepo, query, :two_fields, :desc, expected, @count)
  # end

  # test "paginating by three fields" do
  #   {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
  #   query = from(u in User, as: :user)

  #   expected_results =
  #     TestRepo.all(
  #       from(u in User,
  #         order_by: [
  #           asc_nulls_last: u.last_name,
  #           asc_nulls_last: u.first_name,
  #           desc: u.id
  #         ]
  #       )
  #     )

  #   verify_pagination(TestRepo, query, :three_fields, :asc, expected_results, @count)
  # end

  # test "inverting a three field sort" do
  #   {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
  #   query = from(u in User, as: :user)

  #   expected_results =
  #     TestRepo.all(
  #       from(u in User,
  #         order_by: [
  #           desc_nulls_first: u.last_name,
  #           desc_nulls_first: u.first_name,
  #           asc: u.id
  #         ]
  #       )
  #     )

  #   verify_pagination(TestRepo, query, :three_fields, :desc, expected_results, @count)
  # end

  # test "paginating by four fields" do
  #   {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
  #   query = from(u in User, as: :user)

  #   expected_results =
  #     TestRepo.all(
  #       from(u in User,
  #         order_by: [
  #           desc_nulls_first: u.last_name,
  #           desc_nulls_first: u.first_name,
  #           desc_nulls_first: u.middle_name,
  #           asc: u.id
  #         ]
  #       )
  #     )

  #   verify_pagination(TestRepo, query, :four_fields, :desc, expected_results, @count)
  # end

  # test "inverting a four field sort" do
  #   {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
  #   query = from(u in User, as: :user)

  #   expected_results =
  #     TestRepo.all(
  #       from(u in User,
  #         order_by: [
  #           asc_nulls_last: u.last_name,
  #           asc_nulls_last: u.first_name,
  #           asc_nulls_last: u.middle_name,
  #           desc: u.id
  #         ]
  #       )
  #     )

  #   verify_pagination(TestRepo, query, :four_fields, :asc, expected_results, @count)
  # end

  # test "paginating by UUID" do
  #   {@count, _records} = TestRepo.insert_all(User, Enum.take(user_attrs(), @count))
  #   query = from(u in User, as: :user)

  #   expected_results =
  #     TestRepo.all(from u in User, order_by: [asc_nulls_last: u.last_name, desc: u.public_id])

  #   verify_pagination(TestRepo, query, :uuid, :asc, expected_results, @count)
  # end

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

  # test "sorting by a potentially-missing association" do
  #   user_attrs = Enum.take(user_attrs(), @count)
  #   {_, users} = TestRepo.insert_all(User, user_attrs, returning: true)
  #   user_ids = users |> Enum.map(& &1.id)

  #   phone_attrs = Enum.take(phone_attrs(), @count)
  #   phone_attrs = maybe_assign_user_ids(phone_attrs, user_ids)
  #   TestRepo.insert_all(PhoneNumber, phone_attrs)

  #   query =
  #     from p in PhoneNumber,
  #       as: :phone,
  #       left_join: u in assoc(p, :user),
  #       as: :user,
  #       preload: [user: u]

  #   expected_results =
  #     TestRepo.all(
  #       from p in PhoneNumber,
  #         left_join: u in assoc(p, :user),
  #         order_by: [
  #           asc_nulls_last: u.first_name,
  #           asc: p.id
  #         ],
  #         preload: [user: u]
  #     )

  #   verify_pagination(
  #     TestRepo,
  #     query,
  #     :by_possibly_null_association,
  #     :asc,
  #     expected_results,
  #     @count
  #   )
  # end

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
