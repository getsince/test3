defmodule T.Repo.Migrations.AddTimesLikedAndMatchedProfileFields do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :times_liked, :integer, null: false, default: 0
      add :hidden?, :boolean, null: false, default: true
    end

    create index(:profiles, [:gender, :hidden?, "times_liked desc"], where: ~s["hidden?" = false])
  end
end
