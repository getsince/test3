defmodule T.News.SeenNews do
  use Ecto.Schema

  @primary_key false
  schema "seen_news" do
    field :user_id, Ecto.Bigflake.UUID, primary_key: true
    field :last_id, :integer
  end
end
