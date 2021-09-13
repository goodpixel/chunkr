defmodule Pager.QueryBuilder do
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      import Ecto.Query
    end
  end

  defmacro paginate_by(query_name, do: {:sort, _, args}) do
    sorts = [parse_sorts(args)]
    implement(query_name, sorts)
  end

  defmacro paginate_by(query_name, do: {:__block__, [], sorts}) do
    sorts = Enum.map(sorts, fn {:sort, _, args} -> parse_sorts(args) end)
    implement(query_name, sorts)
  end

  def parse_sorts([dir, field]), do: {dir, field, nil}
  def parse_sorts([dir, field, [type: type]]), do: {dir, field, type}

  def with_cursor_fields_func(query_name, fields) do
    quote do
      def with_cursor_fields(query, unquote(query_name)) do
        select(query, [record], {unquote(fields), record})
      end
    end
  end

  def with_order_func(query_name, order_bys) do
    quote do
      def order(query, unquote(query_name)) do
        Ecto.Query.order_by(query, unquote(order_bys))
      end
    end
  end

  def implement(query_name, sorts) when length(sorts) == 1 do
    [{dir1, f1, t1}] = sorts
    order_bys = Enum.map(sorts, fn {dir, field, _type} -> {dir, field} end)
    fields = Enum.map(sorts, fn {_dir, field, _type} -> field end)
    operators = derive_operators([dir1])
    [op1] = operators
    [rop1] = operators |> Enum.map(&invert/1)

    quote do
      def beyond_cursor(query, cursor, unquote(query_name), :forward) do
        [val1] = Pager.Cursor.decode!(cursor)
        Ecto.Query.where(query, compare(unquote(f1), unquote(op1), val1, unquote(t1)))
      end

      def beyond_cursor(query, cursor, unquote(query_name), :backward) do
        [val1] = Pager.Cursor.decode!(cursor)
        Ecto.Query.where(query, compare(unquote(f1), unquote(rop1), val1, unquote(t1)))
      end

      unquote(with_order_func(query_name, order_bys))
      unquote(with_cursor_fields_func(query_name, fields))
    end
  end

  def implement(query_name, sorts) when length(sorts) == 2 do
    [{dir1, f1, t1}, {dir2, f2, t2}] = sorts
    order_bys = Enum.map(sorts, fn {dir, field, _type} -> {dir, field} end)
    fields = Enum.map(sorts, fn {_dir, field, _type} -> field end)
    operators = derive_operators([dir1, dir2])
    [op1, op2, op3, op4] = operators
    [rop1, rop2, rop3, rop4] = Enum.map(operators, &invert/1)

    quote do
      def beyond_cursor(query, cursor, unquote(query_name), :forward) do
        [val1, val2] = Pager.Cursor.decode!(cursor)

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(op1), val1, unquote(t1)) and
            (compare(unquote(f1), unquote(op2), val1, unquote(t1)) or
               (compare(unquote(f1), unquote(op3), val1, unquote(t1)) and
                  compare(unquote(f2), unquote(op4), val2, unquote(t2))))
        )
      end

      def beyond_cursor(query, cursor, unquote(query_name), :backward) do
        [val1, val2] = Pager.Cursor.decode!(cursor)

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(rop1), val1, unquote(t1)) and
            (compare(unquote(f1), unquote(rop2), val1, unquote(t1)) or
               (compare(unquote(f1), unquote(rop3), val1, unquote(t1)) and
                  compare(unquote(f2), unquote(rop4), val2, unquote(t2))))
        )
      end

      unquote(with_order_func(query_name, order_bys))
      unquote(with_cursor_fields_func(query_name, fields))
    end
  end

  def implement(query_name, sorts) when length(sorts) == 3 do
    [{dir1, f1, t1}, {dir2, f2, t2}, {dir3, f3, t3}] = sorts
    order_bys = Enum.map(sorts, fn {dir, field, _type} -> {dir, field} end)
    fields = Enum.map(sorts, fn {_dir, field, _type} -> field end)
    operators = derive_operators([dir1, dir2, dir3])

    [op1, op2, op3, op4, op5, op6, op7] = operators
    [rop1, rop2, rop3, rop4, rop5, rop6, rop7] = Enum.map(operators, &invert/1)

    quote do
      def beyond_cursor(query, cursor, unquote(query_name), :forward) do
        [val1, val2, val3] = Pager.Cursor.decode!(cursor)

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(op1), val1, unquote(t1)) and
            (compare(unquote(f1), unquote(op2), val1, unquote(t1)) or
               ((compare(unquote(f1), unquote(op3), val1, unquote(t1)) and
                   compare(unquote(f2), unquote(op4), val2, unquote(t2))) or
                  (compare(unquote(f1), unquote(op5), val1, unquote(t1)) and
                     compare(unquote(f2), unquote(op6), val2, unquote(t2)) and
                     compare(unquote(f3), unquote(op7), val3, unquote(t3)))))
        )
      end

      def beyond_cursor(query, cursor, unquote(query_name), :backward) do
        [val1, val2, val3] = Pager.Cursor.decode!(cursor)

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(rop1), val1, unquote(t1)) and
            (compare(unquote(f1), unquote(rop2), val1, unquote(t1)) or
               ((compare(unquote(f1), unquote(rop3), val1, unquote(t1)) and
                   compare(unquote(f2), unquote(rop4), val2, unquote(t2))) or
                  (compare(unquote(f1), unquote(rop5), val1, unquote(t1)) and
                     compare(unquote(f2), unquote(rop6), val2, unquote(t2)) and
                     compare(unquote(f3), unquote(rop7), val3, unquote(t3)))))
        )
      end

      unquote(with_order_func(query_name, order_bys))
      unquote(with_cursor_fields_func(query_name, fields))
    end
  end

  def implement(query_name, sorts) when length(sorts) == 4 do
    [{dir1, f1, t1}, {dir2, f2, t2}, {dir3, f3, t3}, {dir4, f4, t4}] = sorts
    order_bys = Enum.map(sorts, fn {dir, field, _type} -> {dir, field} end)
    fields = Enum.map(sorts, fn {_dir, field, _type} -> field end)
    operators = derive_operators([dir1, dir2, dir3, dir4])

    [op1, op2, op3, op4, op5, op6, op7, op8, op9, op10, op11] = operators

    [rop1, rop2, rop3, rop4, rop5, rop6, rop7, rop8, rop9, rop10, rop11] =
      Enum.map(operators, &invert/1)

    quote do
      def beyond_cursor(query, cursor, unquote(query_name), :forward) do
        [val1, val2, val3, val4] = Pager.Cursor.decode!(cursor)

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(op1), val1, unquote(t1)) and
            (compare(unquote(f1), unquote(op2), val1, unquote(t1)) or
               ((compare(unquote(f1), unquote(op3), val1, unquote(t1)) and
                   compare(unquote(f2), unquote(op4), val2, unquote(t2))) or
                  ((compare(unquote(f1), unquote(op5), val1, unquote(t1)) and
                      compare(unquote(f2), unquote(op6), val2, unquote(t2)) and
                      compare(unquote(f3), unquote(op7), val3, unquote(t3))) or
                     (compare(unquote(f1), unquote(op8), val1, unquote(t1)) and
                        compare(unquote(f2), unquote(op9), val2, unquote(t2)) and
                        compare(unquote(f3), unquote(op10), val3, unquote(t3)) and
                        compare(unquote(f4), unquote(op11), val4, unquote(t4))))))
        )
      end

      def beyond_cursor(query, cursor, unquote(query_name), :backward) do
        [val1, val2, val3, val4] = Pager.Cursor.decode!(cursor)

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(rop1), val1, unquote(t1)) and
            (compare(unquote(f1), unquote(rop2), val1, unquote(t1)) or
               ((compare(unquote(f1), unquote(rop3), val1, unquote(t1)) and
                   compare(unquote(f2), unquote(rop4), val2, unquote(t2))) or
                  ((compare(unquote(f1), unquote(rop5), val1, unquote(t1)) and
                      compare(unquote(f2), unquote(rop6), val2, unquote(t2)) and
                      compare(unquote(f3), unquote(rop7), val3, unquote(t3))) or
                     (compare(unquote(f1), unquote(rop8), val1, unquote(t1)) and
                        compare(unquote(f2), unquote(rop9), val2, unquote(t2)) and
                        compare(unquote(f3), unquote(rop10), val3, unquote(t3)) and
                        compare(unquote(f4), unquote(rop11), val4, unquote(t4))))))
        )
      end

      unquote(with_order_func(query_name, order_bys))
      unquote(with_cursor_fields_func(query_name, fields))
    end
  end

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

  def invert(:eq), do: :eq
  def invert(:gt), do: :lt
  def invert(:gte), do: :lte
  def invert(:lt), do: :gt
  def invert(:lte), do: :gte

  def index_friendly_comparison_operator(:asc), do: :gte
  def index_friendly_comparison_operator(:desc), do: :lte

  def comparison_operator(:asc), do: :gt
  def comparison_operator(:desc), do: :lt

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
