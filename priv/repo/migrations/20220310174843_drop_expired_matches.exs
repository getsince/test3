defmodule T.Repo.Migrations.DropExpiredMatches do
  use Ecto.Migration

  def change do
    drop table(:expired_matches)
  end
end
