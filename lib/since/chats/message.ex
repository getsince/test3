defmodule Since.Chats.Message do
  @moduledoc false
  use Ecto.Schema
  alias Since.Accounts.User
  alias Since.Chats.Chat

  @primary_key {:id, Ecto.Bigflake.UUID, autogenerate: true}
  @foreign_key_type Ecto.Bigflake.UUID
  schema "chat_messages" do
    belongs_to :from_user, User
    belongs_to :to_user, User
    belongs_to :chat, Chat
    field :data, :map
    field :seen, :boolean
    timestamps(updated_at: false)
  end
end
