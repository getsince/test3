defmodule T.Repo.Migrations.AddStickersColumnToProfiles do
  use Ecto.Migration
  import Ecto.Query
  alias T.Accounts.Profile

  def change do
    alter table(:profiles) do
      add :stickers, {:array, :string}
    end
  end
end
