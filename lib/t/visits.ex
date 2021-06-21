defmodule T.Visits do
  alias T.Repo
  alias __MODULE__.Visit

  import Ecto.Changeset

  def save_visit(attrs) do
    %Visit{}
    |> cast(attrs, [:id, :meta])
    |> validate_required([:id])
    # |> validate_format()
    |> Repo.insert()
  end
end
