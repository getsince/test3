defmodule T.Repo.Migrations.AddProfiles do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :blocked_at, :utc_datetime
      add :onboarded_at, :utc_datetime
    end

    create table(:profiles, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), primary_key: true
      add :name, :text
      add :photos, {:array, :text}, default: []
      add :gender, :text
      add :birthdate, :date
      add :height, :integer
      add :home_city, :text
      add :occupation, :text
      add :job, :text
      add :university, :text
      add :major, :text
      add :most_important_in_life, :text
      add :interests, {:array, :text}, default: []
      add :first_date_idea, :text
      add :free_form, :text
      add :music, {:array, :text}, default: []
      add :sports, {:array, :text}, default: []
      add :alcohol, :text
      add :smoking, :text
      add :books, {:array, :text}, default: []
      add :currently_studying, {:array, :text}, default: []
      add :tv_shows, {:array, :text}, default: []
      add :languages, {:array, :text}, default: []
      add :musical_instruments, {:array, :text}, default: []
      add :movies, {:array, :text}, default: []
      add :social_networks, {:array, :text}, default: []
      add :cuisines, {:array, :text}, default: []
      add :pets, {:array, :text}, default: []
    end
  end
end
