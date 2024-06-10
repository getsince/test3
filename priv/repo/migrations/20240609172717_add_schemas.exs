defmodule T.Repo.Migrations.AddSchemas do
  use Ecto.Migration

  @uuid :blob
  @timestamp :integer

  def change do
    # users
    create table(:users, primary_key: false, options: "STRICT, WIHOUT ROWID") do
      add :id, @uuid, primary_key: true, null: false
      add :apple_id, :text
      add :email, :text
      add :blocked_at, @timestamp
      add :onboarded_at, @timestamp
      add :onboarded_with_story_at, @timestamp
    end

    create unique_index(:users, [:apple_id], where: "apple_id IS NOT NULL")

    # profiles
    create table(:profiles, primary_key: false, options: "STRICT, WITHOUT ROWID") do
      add :user_id, references(:users, on_delete: :delete_all, type: @uuid), primary_key: true
      add :name, :text
      add :gender, :text
      add :birthdate, @timestamp
      add :location_x, @integer
      add :location_y, @integer
      add :hidden?, :boolean, null: false, default: true
      add :last_active, @timestamp, null: false
      add :story, :text
      add :min_age, :integer
      add :max_age, :integer
      add :distance, :integer
      add :times_liked, :integer, null: false, default: 0
      add :times_shown, :integer, null: false, default: 0
      add :like_ratio, :float, null: false, default: 0
    end

    # likes
    create table(:liked_profiles, primary_key: false, options: "STRICT, WITHOUT ROWID") do
      add :by_user_id, references(:users, on_delete: :delete_all, type: @uuid), primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: @uuid), primary_key: true
      add :declined, :boolean
      add :seen, :boolean, default: false, null: false
      # TODO
      timestamps(updated_at: false)
    end

    create index(:liked_profiles, [:user_id, :by_user_id])
  end
end
