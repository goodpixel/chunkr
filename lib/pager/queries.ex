defmodule Pager.QueryBuilder do
  defmacro __using__(_) do
    quote do
      require Logger
      import Pager.QueryBuilder
      import Ecto.Query
    end
  end

  defmacro sort(query_name, do: context) do
    {:quote, _, [[do: cursor_fields]]} = context
    implement(query_name, cursor_fields)
  end

  def with_cursor_fields_func(query_name, fields) do
    quote do
      def with_cursor_fields(query, unquote(query_name)) do
        select(query, [record], {unquote(fields), record})
      end
    end
  end

  def implement(query_name, cursor_fields) when length(cursor_fields) == 2 do
    [{dir1, f1}, {dir2, f2}] = cursor_fields
    [op1, op2, op3, op4] = operators([dir1, dir2])

    fields = Enum.map(cursor_fields, fn {_dir, field} -> field end)

    quote do
      def beyond_cursor(query, cursor, unquote(query_name), :forward) do
        [val1, val2] = Pager.Cursor.decode!(cursor)
        # |> IO.inspect(label: "CURSOR VALUES")

        query
        |> Ecto.Query.where(
          compare(unquote(f1), unquote(op1), val1) and
            (compare(unquote(f1), unquote(op2), val1) or
               (compare(unquote(f1), unquote(op3), val1) and
                  compare(unquote(f2), unquote(op4), val2)))
        )
      end

      def order(query, unquote(query_name)) do
        Ecto.Query.order_by(query, unquote(cursor_fields))
      end

      unquote(with_cursor_fields_func(query_name, fields))
    end
  end

  def operators([dir1]) do
    [
      cursor_comparison(dir1)
    ]
  end

  def operators([dir1, dir2]) do
    [
      index_friendly_cursor_comparison(dir1),
      cursor_comparison(dir1),
      :eq,
      cursor_comparison(dir2)
    ]
  end

  def index_friendly_cursor_comparison(:asc), do: :gte
  def index_friendly_cursor_comparison(:desc), do: :lte

  def cursor_comparison(:asc), do: :gt
  def cursor_comparison(:desc), do: :lt

  defmacro compare(field, :gte, value) do
    quote do: unquote(field) >= ^unquote(value)
  end

  defmacro compare(field, :gt, value) do
    quote do: unquote(field) > ^unquote(value)
  end

  defmacro compare(field, :eq, value) do
    quote do: unquote(field) == ^unquote(value)
  end

  defmacro compare(field, :lt, value) do
    quote do: unquote(field) < ^unquote(value)
  end

  defmacro compare(field, :lte, value) do
    quote do: unquote(field) <= ^unquote(value)
  end
end
