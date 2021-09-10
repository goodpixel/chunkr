defmodule Pager.User do
  @moduledoc false
  use Ecto.Schema

  @timestamps_opts [type: :utc_datetime_usec]
  schema "users" do
    field(:first_name, :string)
    field(:middle_name, :string)
    field(:last_name, :string)

    timestamps()
  end
end
