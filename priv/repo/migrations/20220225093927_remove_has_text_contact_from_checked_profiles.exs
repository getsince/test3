defmodule T.Repo.Migrations.RemoveHasTextContactFromCheckedProfiles do
  use Ecto.Migration

  def change do
    alter table(:checked_profiles) do
      remove :has_text_contact?
    end
  end
end
