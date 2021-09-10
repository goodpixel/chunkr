defmodule Pager.User do
  @moduledoc false
  use Ecto.Schema

  @timestamps_opts [type: :utc_datetime_usec]
  schema "users" do
    field :public_id, :binary_id
    field :first_name, :string
    field :middle_name, :string
    field :last_name, :string

    has_many :phone_numbers, Pager.PhoneNumber

    timestamps()
  end
end
