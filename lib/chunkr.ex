defmodule Chunkr do
  @moduledoc false

  @default_max_limit 100
  @default_opts [cursor_mod: Chunkr.Cursor.Base64, max_limit: @default_max_limit]

  @doc false
  defmacro __using__(config) do
    quote do
      def paginate!(queryable, opts) do
        default_opts = unquote(config) ++ [{:repo, __MODULE__} | unquote(@default_opts)]
        Chunkr.Pagination.paginate!(queryable, opts ++ default_opts)
      end

      def paginate(queryable, opts) do
        default_opts = unquote(config) ++ [{:repo, __MODULE__} | unquote(@default_opts)]
        Chunkr.Pagination.paginate(queryable, opts ++ default_opts)
      end
    end
  end

  @doc false
  def default_max_limit(), do: @default_max_limit
end
