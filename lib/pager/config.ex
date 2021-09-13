defmodule Pager.Config do
  @enforce_keys [:queries, :repo]
  defstruct [:queries, :repo]

  @type t :: %__MODULE__{queries: atom(), repo: atom()}

  def new(opts) do
    opts = opts |> Enum.into(%{})
    struct!(__MODULE__, opts)
  end
end
