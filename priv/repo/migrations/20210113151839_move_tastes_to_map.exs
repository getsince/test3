defmodule T.Repo.Migrations.MoveTastesToMap do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add :tastes, :jsonb, default: "{}", null: false
      remove :music, {:array, :text}, default: []
      remove :sports, {:array, :text}, default: []
      remove :alcohol, :text
      remove :smoking, :text
      remove :books, {:array, :text}, default: []
      remove :currently_studying, {:array, :text}, default: []
      remove :tv_shows, {:array, :text}, default: []
      remove :languages, {:array, :text}, default: []
      remove :musical_instruments, {:array, :text}, default: []
      remove :movies, {:array, :text}, default: []
      remove :social_networks, {:array, :text}, default: []
      remove :cuisines, {:array, :text}, default: []
      remove :pets, {:array, :text}, default: []
    end
  end
end
