defmodule T.Repo.Migrations.AddStickersColumnToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :stickers, {:array, :string}
    end
  end
end
