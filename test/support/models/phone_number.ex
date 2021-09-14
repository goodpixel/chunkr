defmodule Chunkr.PhoneNumber do
  @moduledoc false
  use Ecto.Schema

  @timestamps_opts [type: :utc_datetime_usec]
  schema "phone_numbers" do
    field(:number, :string)

    belongs_to :user, Chunkr.User

    timestamps()
  end
end
