defmodule PagerTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  use Pager.PaginationTests
  import Ecto.Query
  import Pager.PaginationHelpers

  doctest Pager

  alias Pager.{PhoneNumber, TestQueries, TestRepo, User}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Pager.TestRepo)
  end

  verify_pagination(TestRepo, TestQueries, :single_field,
    pre: fn %{users: attrs} -> TestRepo.insert_all(User, attrs) end,
    query: from(u in User, as: :user),
    post: fn -> TestRepo.delete_all(User) end
  )

  verify_pagination(TestRepo, TestQueries, :two_fields,
    pre: fn %{users: attrs} -> TestRepo.insert_all(User, attrs) end,
    query: from(u in User, as: :user),
    post: fn -> TestRepo.delete_all(User) end
  )

  verify_pagination(TestRepo, TestQueries, :three_fields,
    pre: fn %{users: attrs} -> TestRepo.insert_all(User, attrs) end,
    query: from(u in User, as: :user),
    post: fn -> TestRepo.delete_all(User) end
  )

  verify_pagination(TestRepo, TestQueries, :four_fields,
    pre: fn %{users: attrs} -> TestRepo.insert_all(User, attrs) end,
    query: from(u in User, as: :user),
    post: fn -> TestRepo.delete_all(User) end
  )

  verify_pagination(TestRepo, TestQueries, :with_uuid,
    pre: fn %{users: attrs} -> TestRepo.insert_all(User, attrs) end,
    query: from(u in User, as: :user),
    post: fn -> TestRepo.delete_all(User) end
  )

  verify_pagination(TestRepo, TestQueries, :with_subquery,
    pre: fn %{users: user_attrs, phones: phone_attrs} ->
      {_, users} = TestRepo.insert_all(User, user_attrs, returning: true)
      user_ids = users |> Enum.map(& &1.id)
      phone_attrs = maybe_assign_user_ids(phone_attrs, user_ids)
      TestRepo.insert_all(PhoneNumber, phone_attrs)
    end,
    query:
      from(u in User,
        as: :user,
        left_lateral_join:
          phones in subquery(
            from p in PhoneNumber,
              distinct: p.user_id,
              select: %{user_id: p.user_id, created_at: p.inserted_at},
              order_by: [desc: p.inserted_at]
          ),
        on: phones.user_id == u.id,
        as: :phones
      ),
    post: fn -> TestRepo.delete_all(User) end
  )

  verify_pagination(TestRepo, TestQueries, :by_possibly_null_association,
    pre: fn %{users: user_attrs, phones: phone_attrs} ->
      {_, users} = TestRepo.insert_all(User, user_attrs, returning: true)
      user_ids = users |> Enum.map(& &1.id)
      phone_attrs = maybe_assign_user_ids(phone_attrs, user_ids)
      TestRepo.insert_all(PhoneNumber, phone_attrs)
    end,
    query: from(p in PhoneNumber, as: :phone, left_join: u in assoc(p, :user), as: :user),
    post: fn ->
      TestRepo.delete_all(User)
      TestRepo.delete_all(PhoneNumber)
    end
  )
end
