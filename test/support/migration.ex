defmodule Chunkr.Migration do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:users) do
      add :public_id, :binary_id, null: false
      add :first_name, :text
      add :middle_name, :text
      add :last_name, :text
      timestamps()
    end

    create table(:phone_numbers) do
      add :number, :text
      add :user_id, references(:users, on_delete: :delete_all)
      timestamps()
    end
  end
end
