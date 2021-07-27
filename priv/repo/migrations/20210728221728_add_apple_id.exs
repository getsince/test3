defmodule T.Repo.Migrations.AddAppleId do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :apple_id, :string
      modify :phone_number, :string, null: true
    end

    drop unique_index(:users, [:phone_number])

    # TODO need where?
    create unique_index(:users, [:phone_number], where: "phone_number is not null")
    create unique_index(:users, [:apple_id], where: "apple_id is not null")
  end
end
