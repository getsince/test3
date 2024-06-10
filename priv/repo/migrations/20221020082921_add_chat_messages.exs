defmodule Since.Repo.Migrations.AddChatMessages do
  use Ecto.Migration

  @opts [on_delete: :delete_all, type: :uuid]

  def change do
    create table(:chat_messages, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :chat_id, references(:chats, @opts), null: false
      add :from_user_id, references(:users, @opts), null: false
      add :to_user_id, references(:users, @opts), null: false
      add :data, :jsonb, null: false
      add :seen, :boolean, null: false, default: false
      timestamps(updated_at: false)
    end

    create index(:chat_messages, [:chat_id])
  end
end
