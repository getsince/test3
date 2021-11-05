defmodule T.Repo.Migrations.AddAppVersionToUserTokens do
  use Ecto.Migration

  def change do
    alter table(:users_tokens) do
      add :version, :string
    end
  end
end
