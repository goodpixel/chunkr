defmodule Pager.Config do
  @enforce_keys [:queries, :repo]
  defstruct [:queries, :repo]

  def new(opts) do
    opts = opts |> Enum.into(%{})
    struct!(__MODULE__, opts)
  end
end
