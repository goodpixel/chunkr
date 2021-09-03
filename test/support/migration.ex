defmodule Pager.Migration do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:users) do
      add :first_name, :text
      add :middle_name, :text
      add :last_name, :text
      timestamps()
    end
  end
end
