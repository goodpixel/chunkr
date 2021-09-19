defmodule Chunkr.PaginationPlanner do
  @moduledoc """
  Provides a set of macros for generating functions to assist with paginating queries. For example:

      defmodule MyApp.PaginationPlanner do
        use Chunkr.PaginationPlanner

        paginate_by :user_created_at do
          sort :desc, as(:user).inserted_at
          sort :desc, as(:user).id, type: :binary_id
        end

        paginate_by :user_name do
          sort :asc, fragment("lower(coalesce(?, 'zzz')"), as(:user).name).inserted_at
          sort :desc, as(:user).id, type: :binary_id
        end
      end

  The `paginate_by/1` macro above takes a query name and sets up the necessary `beyond_cursor/4`,
  `apply_order/4`, and `apply_select/2` functions based on the number of sort options passed in the
  block as well as the sort directions specified.

  Each call to `sort/3` must include the sort direction, the field to be sorted, and an optional
  `:type` keyword. If `:type` is provided, the cursor value will be cast as that type for the
  sake of comparisons. See Ecto.Query.API.type/2.

  ## Ordering

  In keyset-based pagination, it is essential that results are deterministically ordered, otherwise
  you may see unexpected results. Therefore, the final column used for sorting must _always_ be
  unique and non-NULL.

  Ordering of paginated results can be based on columns from the primary table, any joined table,
  any subquery, or any dynamically computed value based on other fields. Regardless of where the
  column resides, named bindings are always required…

  ## Named bindings

  Because these `sort/3` clauses must reference bindings that have not yet been established, each
  sort clause must use `:as` to take advantage of late binding. A parallel `:as` must then be used
  within the query that gets passed to `Chunkr.Pagination.paginate/4` or the query will fail. See
  [Ecto Named bindings](https://hexdocs.pm/ecto/Ecto.Query.html#module-named-bindings) for more.

  ## NULL values in sort fields

  When using comparison operators in SQL, records involving comparisons against `NULL` get dropped.
  This is generally undesirable for pagination, as the goal is usually to work your way through an
  entire result set in chunks—not just through the part of the result set that doesn't have NULL
  values in the important fields. For example, when sorting users by [last name, first name,
  middle name], you most likely don't want to exclude users without a known middle name.

  To work around this awkwardness, you'll need to pick a value that is almost sure to come before
  or after the rest of your results (depending on whether you want `NULL` values to sort to the
  beginning or the end of your results). It's not good enough to think you can simply use a strategy
  like ordering by `NULLS LAST` because the filtering of values up to the cursor values will use
  comparison operators—which will cause records with relevant NULL values to be dropped entirely.

  The following `fragment` example sets up names to be compared in a case-insensitive fashion
  and places records with a `NULL` name at the end of the list (assuming no names will sort beyond
  "zzz"!).

      sort :asc, fragment("lower(coalesce(?, 'zzz')"), as(:user).name).inserted_at

  ## Limitations

  _Note that Chunkr limits the number of `sort` clauses to 4._
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
  def derive_operators([dir1]) do
    [
      comparison_operator(dir1)
    ]
  end

  def derive_operators([dir1, dir2]) do
    [
      index_friendly_comparison_operator(dir1),
      comparison_operator(dir1),
      :eq,
      comparison_operator(dir2)
    ]
  end

  def derive_operators([dir1, dir2, dir3]) do
    [
      index_friendly_comparison_operator(dir1),
      comparison_operator(dir1),
      :eq,
      comparison_operator(dir2),
      :eq,
      :eq,
      comparison_operator(dir3)
    ]
  end

  def derive_operators([dir1, dir2, dir3, dir4]) do
    [
      index_friendly_comparison_operator(dir1),
      comparison_operator(dir1),
      :eq,
      comparison_operator(dir2),
      :eq,
      :eq,
      comparison_operator(dir3),
      :eq,
      :eq,
      :eq,
      comparison_operator(dir4)
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
