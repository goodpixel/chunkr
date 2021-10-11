defmodule Chunkr.PaginationPlanner do
  @moduledoc """
  Macros for establishing your pagination strategies.

  For example:

      defmodule MyApp.PaginationPlanner do
        use Chunkr.PaginationPlanner

        # Sort by a single column.
        paginate_by :username do
          sort :asc, as(:user).username
        end

        # Sort by DESC `user.inserted_at`, with ASC `user.id` as a tiebreaker.
        # In this case, `user.id` is explicitly called out as a UUID.
        paginate_by :user_created_at do
          sort :desc, as(:user).inserted_at
          sort :asc, as(:user).id, type: :binary_id
        end

        # Sort names in ASC order.
        # Coalesce any `NULL` name values so they're at the end of the result set.
        # Use `user.id` as the tiebreaker.
        paginate_by :last_name do
          sort :asc, fragment("coalesce(?, 'zzz')", as(:user).last_name)
          sort :asc, fragment("coalesce(?, 'zzz')", as(:user).first_name)
          sort :desc, as(:user).id
        end
      end

  The `paginate_by/2` macro above takes a name for the pagination strategy along with the
  fields to sort by in their desired order. The fields can be actual table columns or
  dynamically-generated values via Ecto fragments. Fragments are especially handy for
  implementing case-insensitive sorts, coalescing `NULL` values, and so forth.

  Each call to `sort` requires a sort direction (`:asc` or `:desc`), any valid Ecto fragment
  or field (using [`:as`](https://hexdocs.pm/ecto/Ecto.Query.html#module-named-bindings)), and an
  optional [`:type`](https://hexdocs.pm/ecto/3.7.1/Ecto.Query.API.html#type/2) keyword.
  If `:type` is provided, the relevant cursor value will be cast to that type when filtering records.

  The result of registering these pagination strategies is that, at compile time, Chunkr
  automatically defines the functions necessary to take future queries and extend them for
  your desired pagination strategies. This involves dynamically implementing functions to sort,
  filter, and limit your queries according to these strategies as well as functions to select
  both the fields needed for the cursor as well as the records themselves.

  ## Ordering

  It is essential that your results are deterministically ordered, otherwise you will see
  unexpected results. Therefore, the final column used for sorting (i.e. the ultimate tie-breaker)
  must _always_ be unique and non-NULL.

  ## Named bindings

  Because these sort clauses must reference bindings that have not yet been established,
  we use [`:as`](https://hexdocs.pm/ecto/Ecto.Query.html#module-named-bindings)
  to take advantage of Ecto's late binding. The column referenced by `:as` must then be
  explicitly provided within your query or it fail.

  ## Always coalesce `NULL` values!

  SQL cannot reasonably compare `NULL` to a non-`NULL` value using operators like `<` and `>`.
  However, when filtering records against our cursor values, it's not uncommon to find ourselves
  in a situation where our sorted fields may include `NULL` values. Without intervention, any
  records that contain a `NULL` value in one of the sort fields would be entirely dropped from the
  result set, which is almost surely _not_ the intention.

  To work around this awkwardness, you'll need to pick a value that is almost sure to come before
  or after the rest of your results (depending on whether you want `NULL` values to sort to the
  beginning or the end of your results respectively) and coalesce any `NULL` values in sorted
  fields so that these records sort to the desired location. With keyset-based pagination,
  it's not enough to use a strategy like ordering by `NULLS LAST` or `NULLS FIRST`.
  Remember, it's not the ordering itself where this is problematic; it's the efficient filtering
  of records (via comparison to a cursor) where records with `NULL` values would get dropped.

  Note that you only need to coalesce values within your actual pagination strategy, and the
  coalesced values will only be used behind the scenes (for cursor values and when filtering
  records against cursors). You **_do not_** need to coalesce values in the query that you
  provide to `Chunkr.Pagination.paginate/4`, and you need not worry about values somehow being
  altered by Chunkr in the records that are returned in each page of results.

  ## Indexes

  In order to get maximum performance from your paginated queries, you'll want to
  create database indexes that align with your pagination strategy. When sorting by multiple
  columns, you will need to have an index in place that includes each of those columns with
  sort orders matching your strategy. However, you shouldn't need to include the inverse order
  as the database should be able to recognize and automatically reverse the index order when
  necessary. By providing an index that matches your pagination strategy, you should be able to
  take advantage of [efficient pipelined top-N queries](https://use-the-index-luke.com/sql/partial-results/top-n-queries).

  ## Limitations

  Chunkr limits the number of `sort` clauses to 4.
  """

  @doc false
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      require Ecto.Query

      def apply_limit(query, limit) do
        Ecto.Query.limit(query, ^limit)
      end
    end
  end

  @doc """
  Implements the functions necessary for pagination.

      paginate_by :user_id do
        sort :asc, as(:user).id
      end
  """
  defmacro paginate_by(query_name, do: {:sort, _, args}) do
    sorts = [parse_sorts(args)]
    implement(query_name, sorts)
  end

  defmacro paginate_by(query_name, do: {:__block__, _, sorts}) do
    sorts = Enum.map(sorts, fn {:sort, _, args} -> parse_sorts(args) end)
    implement(query_name, sorts)
  end

  @doc false
  def parse_sorts([dir, field]), do: {dir, field, nil}
  def parse_sorts([dir, field, [type: type]]), do: {dir, field, type}

  @doc false
  def with_cursor_fields_func(query_name, fields) do
    quote do
      def apply_select(query, unquote(query_name)) do
        Ecto.Query.select(query, [record], {unquote(fields), record})
      end
    end
  end

  @doc false
  def with_order_func(query_name, primary_sort_dir, order_bys) do
    inverted_sort_dir = invert(primary_sort_dir)

    quote do
      def apply_order(query, unquote(query_name), unquote(primary_sort_dir), :forward) do
        Ecto.Query.order_by(query, unquote(order_bys))
      end

      def apply_order(query, unquote(query_name), unquote(primary_sort_dir), :backward) do
        Ecto.Query.order_by(query, unquote(order_bys))
        |> Ecto.Query.reverse_order()
      end

      def apply_order(query, unquote(query_name), unquote(inverted_sort_dir), :forward) do
        Ecto.Query.order_by(query, unquote(order_bys))
        |> Ecto.Query.reverse_order()
      end

      def apply_order(query, unquote(query_name), unquote(inverted_sort_dir), :backward) do
        Ecto.Query.order_by(query, unquote(order_bys))
      end
    end
  end

  @doc false
  def implement(query_name, sorts) when length(sorts) == 1 do
    [{dir1, f1, t1}] = sorts
    rdir1 = invert(dir1)

    operators = derive_operators([dir1])
    [op1] = operators
    [rop1] = operators |> Enum.map(&invert/1)

    order_bys = Enum.map(sorts, fn {dir, field, _type} -> {dir, field} end)
    fields = Enum.map(sorts, fn {_dir, field, _type} -> field end)

    quote do
      def beyond_cursor(query, unquote(query_name), unquote(dir1), :forward, cursor_values) do
        [cv1] = cursor_values
        Ecto.Query.where(query, compare(unquote(f1), unquote(op1), cv1, unquote(t1)))
      end

      def beyond_cursor(query, unquote(query_name), unquote(dir1), :backward, cursor_values) do
        [cv1] = cursor_values
        Ecto.Query.where(query, compare(unquote(f1), unquote(rop1), cv1, unquote(t1)))
      end

      def beyond_cursor(query, unquote(query_name), unquote(rdir1), :forward, cursor_values) do
        [cv1] = cursor_values
        Ecto.Query.where(query, compare(unquote(f1), unquote(rop1), cv1, unquote(t1)))
      end

      def beyond_cursor(query, unquote(query_name), unquote(rdir1), :backward, cursor_values) do
        [cv1] = cursor_values
        Ecto.Query.where(query, compare(unquote(f1), unquote(op1), cv1, unquote(t1)))
      end

      unquote(with_order_func(query_name, dir1, order_bys))
      unquote(with_cursor_fields_func(query_name, fields))
    end
  end

  def implement(query_name, sorts) when length(sorts) == 2 do
    [{dir1, f1, t1}, {dir2, f2, t2}] = sorts
    rdir1 = invert(dir1)

    operators = derive_operators([dir1, dir2])
    [op1, op2, op3, op4] = operators
    [rop1, rop2, rop3, rop4] = Enum.map(operators, &invert/1)

    order_bys = Enum.map(sorts, fn {dir, field, _type} -> {dir, field} end)
    fields = Enum.map(sorts, fn {_dir, field, _type} -> field end)

    quote do
      def beyond_cursor(query, unquote(query_name), unquote(dir1), :forward, cursor_values) do
        [cv1, cv2] = cursor_values

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(op1), cv1, unquote(t1)) and
            (compare(unquote(f1), unquote(op2), cv1, unquote(t1)) or
               (compare(unquote(f1), unquote(op3), cv1, unquote(t1)) and
                  compare(unquote(f2), unquote(op4), cv2, unquote(t2))))
        )
      end

      def beyond_cursor(query, unquote(query_name), unquote(dir1), :backward, cursor_values) do
        [cv1, cv2] = cursor_values

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(rop1), cv1, unquote(t1)) and
            (compare(unquote(f1), unquote(rop2), cv1, unquote(t1)) or
               (compare(unquote(f1), unquote(rop3), cv1, unquote(t1)) and
                  compare(unquote(f2), unquote(rop4), cv2, unquote(t2))))
        )
      end

      def beyond_cursor(query, unquote(query_name), unquote(rdir1), :forward, cursor_values) do
        [cv1, cv2] = cursor_values

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(rop1), cv1, unquote(t1)) and
            (compare(unquote(f1), unquote(rop2), cv1, unquote(t1)) or
               (compare(unquote(f1), unquote(rop3), cv1, unquote(t1)) and
                  compare(unquote(f2), unquote(rop4), cv2, unquote(t2))))
        )
      end

      def beyond_cursor(query, unquote(query_name), unquote(rdir1), :backward, cursor_values) do
        [cv1, cv2] = cursor_values

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(op1), cv1, unquote(t1)) and
            (compare(unquote(f1), unquote(op2), cv1, unquote(t1)) or
               (compare(unquote(f1), unquote(op3), cv1, unquote(t1)) and
                  compare(unquote(f2), unquote(op4), cv2, unquote(t2))))
        )
      end

      unquote(with_order_func(query_name, dir1, order_bys))
      unquote(with_cursor_fields_func(query_name, fields))
    end
  end

  @doc false
  def implement(query_name, sorts) when length(sorts) == 3 do
    [{dir1, f1, t1}, {dir2, f2, t2}, {dir3, f3, t3}] = sorts
    rdir1 = invert(dir1)

    operators = derive_operators([dir1, dir2, dir3])

    [op1, op2, op3, op4, op5, op6, op7] = operators
    [rop1, rop2, rop3, rop4, rop5, rop6, rop7] = Enum.map(operators, &invert/1)

    order_bys = Enum.map(sorts, fn {dir, field, _type} -> {dir, field} end)
    fields = Enum.map(sorts, fn {_dir, field, _type} -> field end)

    quote do
      def beyond_cursor(query, unquote(query_name), unquote(dir1), :forward, cursor_values) do
        [cv1, cv2, cv3] = cursor_values

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(op1), cv1, unquote(t1)) and
            (compare(unquote(f1), unquote(op2), cv1, unquote(t1)) or
               ((compare(unquote(f1), unquote(op3), cv1, unquote(t1)) and
                   compare(unquote(f2), unquote(op4), cv2, unquote(t2))) or
                  (compare(unquote(f1), unquote(op5), cv1, unquote(t1)) and
                     compare(unquote(f2), unquote(op6), cv2, unquote(t2)) and
                     compare(unquote(f3), unquote(op7), cv3, unquote(t3)))))
        )
      end

      def beyond_cursor(query, unquote(query_name), unquote(dir1), :backward, cursor_values) do
        [cv1, cv2, cv3] = cursor_values

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(rop1), cv1, unquote(t1)) and
            (compare(unquote(f1), unquote(rop2), cv1, unquote(t1)) or
               ((compare(unquote(f1), unquote(rop3), cv1, unquote(t1)) and
                   compare(unquote(f2), unquote(rop4), cv2, unquote(t2))) or
                  (compare(unquote(f1), unquote(rop5), cv1, unquote(t1)) and
                     compare(unquote(f2), unquote(rop6), cv2, unquote(t2)) and
                     compare(unquote(f3), unquote(rop7), cv3, unquote(t3)))))
        )
      end

      def beyond_cursor(query, unquote(query_name), unquote(rdir1), :forward, cursor_values) do
        [cv1, cv2, cv3] = cursor_values

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(rop1), cv1, unquote(t1)) and
            (compare(unquote(f1), unquote(rop2), cv1, unquote(t1)) or
               ((compare(unquote(f1), unquote(rop3), cv1, unquote(t1)) and
                   compare(unquote(f2), unquote(rop4), cv2, unquote(t2))) or
                  (compare(unquote(f1), unquote(rop5), cv1, unquote(t1)) and
                     compare(unquote(f2), unquote(rop6), cv2, unquote(t2)) and
                     compare(unquote(f3), unquote(rop7), cv3, unquote(t3)))))
        )
      end

      def beyond_cursor(query, unquote(query_name), unquote(rdir1), :backward, cursor_values) do
        [cv1, cv2, cv3] = cursor_values

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(op1), cv1, unquote(t1)) and
            (compare(unquote(f1), unquote(op2), cv1, unquote(t1)) or
               ((compare(unquote(f1), unquote(op3), cv1, unquote(t1)) and
                   compare(unquote(f2), unquote(op4), cv2, unquote(t2))) or
                  (compare(unquote(f1), unquote(op5), cv1, unquote(t1)) and
                     compare(unquote(f2), unquote(op6), cv2, unquote(t2)) and
                     compare(unquote(f3), unquote(op7), cv3, unquote(t3)))))
        )
      end

      unquote(with_order_func(query_name, dir1, order_bys))
      unquote(with_cursor_fields_func(query_name, fields))
    end
  end

  def implement(query_name, sorts) when length(sorts) == 4 do
    [{dir1, f1, t1}, {dir2, f2, t2}, {dir3, f3, t3}, {dir4, f4, t4}] = sorts
    rdir1 = invert(dir1)

    order_bys = Enum.map(sorts, fn {dir, field, _type} -> {dir, field} end)
    fields = Enum.map(sorts, fn {_dir, field, _type} -> field end)
    operators = derive_operators([dir1, dir2, dir3, dir4])

    [op1, op2, op3, op4, op5, op6, op7, op8, op9, op10, op11] = operators

    [rop1, rop2, rop3, rop4, rop5, rop6, rop7, rop8, rop9, rop10, rop11] =
      Enum.map(operators, &invert/1)

    quote do
      def beyond_cursor(query, unquote(query_name), unquote(dir1), :forward, cursor_values) do
        [cv1, cv2, cv3, cv4] = cursor_values

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(op1), cv1, unquote(t1)) and
            (compare(unquote(f1), unquote(op2), cv1, unquote(t1)) or
               ((compare(unquote(f1), unquote(op3), cv1, unquote(t1)) and
                   compare(unquote(f2), unquote(op4), cv2, unquote(t2))) or
                  ((compare(unquote(f1), unquote(op5), cv1, unquote(t1)) and
                      compare(unquote(f2), unquote(op6), cv2, unquote(t2)) and
                      compare(unquote(f3), unquote(op7), cv3, unquote(t3))) or
                     (compare(unquote(f1), unquote(op8), cv1, unquote(t1)) and
                        compare(unquote(f2), unquote(op9), cv2, unquote(t2)) and
                        compare(unquote(f3), unquote(op10), cv3, unquote(t3)) and
                        compare(unquote(f4), unquote(op11), cv4, unquote(t4))))))
        )
      end

      def beyond_cursor(query, unquote(query_name), unquote(dir1), :backward, cursor_values) do
        [cv1, cv2, cv3, cv4] = cursor_values

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(rop1), cv1, unquote(t1)) and
            (compare(unquote(f1), unquote(rop2), cv1, unquote(t1)) or
               ((compare(unquote(f1), unquote(rop3), cv1, unquote(t1)) and
                   compare(unquote(f2), unquote(rop4), cv2, unquote(t2))) or
                  ((compare(unquote(f1), unquote(rop5), cv1, unquote(t1)) and
                      compare(unquote(f2), unquote(rop6), cv2, unquote(t2)) and
                      compare(unquote(f3), unquote(rop7), cv3, unquote(t3))) or
                     (compare(unquote(f1), unquote(rop8), cv1, unquote(t1)) and
                        compare(unquote(f2), unquote(rop9), cv2, unquote(t2)) and
                        compare(unquote(f3), unquote(rop10), cv3, unquote(t3)) and
                        compare(unquote(f4), unquote(rop11), cv4, unquote(t4))))))
        )
      end

      def beyond_cursor(query, unquote(query_name), unquote(rdir1), :forward, cursor_values) do
        [cv1, cv2, cv3, cv4] = cursor_values

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(rop1), cv1, unquote(t1)) and
            (compare(unquote(f1), unquote(rop2), cv1, unquote(t1)) or
               ((compare(unquote(f1), unquote(rop3), cv1, unquote(t1)) and
                   compare(unquote(f2), unquote(rop4), cv2, unquote(t2))) or
                  ((compare(unquote(f1), unquote(rop5), cv1, unquote(t1)) and
                      compare(unquote(f2), unquote(rop6), cv2, unquote(t2)) and
                      compare(unquote(f3), unquote(rop7), cv3, unquote(t3))) or
                     (compare(unquote(f1), unquote(rop8), cv1, unquote(t1)) and
                        compare(unquote(f2), unquote(rop9), cv2, unquote(t2)) and
                        compare(unquote(f3), unquote(rop10), cv3, unquote(t3)) and
                        compare(unquote(f4), unquote(rop11), cv4, unquote(t4))))))
        )
      end

      def beyond_cursor(query, unquote(query_name), unquote(rdir1), :backward, cursor_values) do
        [cv1, cv2, cv3, cv4] = cursor_values

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(op1), cv1, unquote(t1)) and
            (compare(unquote(f1), unquote(op2), cv1, unquote(t1)) or
               ((compare(unquote(f1), unquote(op3), cv1, unquote(t1)) and
                   compare(unquote(f2), unquote(op4), cv2, unquote(t2))) or
                  ((compare(unquote(f1), unquote(op5), cv1, unquote(t1)) and
                      compare(unquote(f2), unquote(op6), cv2, unquote(t2)) and
                      compare(unquote(f3), unquote(op7), cv3, unquote(t3))) or
                     (compare(unquote(f1), unquote(op8), cv1, unquote(t1)) and
                        compare(unquote(f2), unquote(op9), cv2, unquote(t2)) and
                        compare(unquote(f3), unquote(op10), cv3, unquote(t3)) and
                        compare(unquote(f4), unquote(op11), cv4, unquote(t4))))))
        )
      end

      unquote(with_order_func(query_name, dir1, order_bys))
      unquote(with_cursor_fields_func(query_name, fields))
    end
  end

  @doc false
  def derive_operators([single_sort_dir]), do: [comparison_operator(single_sort_dir)]

  def derive_operators([dir1 | _rest] = multiple_sort_dirs) do
    multiple_sort_dirs
    |> Enum.with_index(1)
    |> Enum.reduce(index_friendly_comparison_operator(dir1), fn {dir, sort_col_num}, operators ->
      [operators, operators_for_sort_field(sort_col_num, dir)]
    end)
    |> List.flatten()
  end

  defp operators_for_sort_field(sort_col_num, sort_col_dir) do
    [
      List.duplicate(:eq, sort_col_num - 1),
      comparison_operator(sort_col_dir)
    ]
  end

  @doc false
  def invert(:asc), do: :desc
  def invert(:desc), do: :asc

  def invert(:eq), do: :eq
  def invert(:gt), do: :lt
  def invert(:gte), do: :lte
  def invert(:lt), do: :gt
  def invert(:lte), do: :gte

  @doc false
  def index_friendly_comparison_operator(:asc), do: :gte
  def index_friendly_comparison_operator(:desc), do: :lte

  @doc false
  def comparison_operator(:asc), do: :gt
  def comparison_operator(:desc), do: :lt

  @doc false
  defmacro compare(field, :gte, value, nil) do
    quote do: unquote(field) >= ^unquote(value)
  end

  defmacro compare(field, :gte, value, type) do
    quote do: unquote(field) >= type(^unquote(value), unquote(type))
  end

  defmacro compare(field, :gt, value, nil) do
    quote do: unquote(field) > ^unquote(value)
  end

  defmacro compare(field, :gt, value, type) do
    quote do: unquote(field) > type(^unquote(value), unquote(type))
  end

  defmacro compare(field, :eq, value, nil) do
    quote do: unquote(field) == ^unquote(value)
  end

  defmacro compare(field, :eq, value, type) do
    quote do: unquote(field) == type(^unquote(value), unquote(type))
  end

  defmacro compare(field, :lt, value, nil) do
    quote do: unquote(field) < ^unquote(value)
  end

  defmacro compare(field, :lt, value, type) do
    quote do: unquote(field) < type(^unquote(value), unquote(type))
  end

  defmacro compare(field, :lte, value, nil) do
    quote do: unquote(field) <= ^unquote(value)
  end

  defmacro compare(field, :lte, value, type) do
    quote do: unquote(field) <= type(^unquote(value), unquote(type))
  end
end
