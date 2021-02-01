defmodule T.Support do
  alias __MODULE__.Message
  alias T.{Repo, Matches}
  import Ecto.Query

  @pubsub T.PubSub
  @topic to_string(__MODULE__)

  def subscribe_to_all_messages do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  defp notify_subscribers({:error, _reason} = error, _event) do
    error
  end

  defp notify_subscribers({:ok, value} = success, event) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {__MODULE__, event, value})
    success
  end

  def add_message(user_id, author_id, attrs) do
    %Message{id: Ecto.Bigflake.UUID.autogenerate(), author_id: author_id, user_id: user_id}
    |> Matches.message_changeset(attrs)
    |> Repo.insert()
    |> notify_subscribers([:message, :created])
  end

  def list_messages(user_id, opts \\ []) do
    q =
      Message
      |> where(user_id: ^user_id)
      |> order_by([m], asc: m.id)

    q =
      if after_id = opts[:after] do
        where(q, [m], m.id > ^after_id)
      else
        q
      end

    Repo.all(q)
  end

  def list_last_messages do
    Message
    |> order_by([m], desc: m.inserted_at)
    |> distinct([m], m.user_id)
    |> Repo.all()
  end
end
