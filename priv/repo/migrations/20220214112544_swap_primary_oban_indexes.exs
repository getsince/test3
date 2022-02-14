# https://hexdocs.pm/oban/v2-11.html#swap-the-compound-index-optional-but-recommended
defmodule T.Repo.Migrations.SwapPrimaryObanIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists index(
                           :oban_jobs,
                           [:state, :queue, :priority, :scheduled_at, :id],
                           concurrently: true
                         )

    drop_if_exists index(
                     :oban_jobs,
                     [:queue, :state, :priority, :scheduled_at, :id]
                   )
  end
end
