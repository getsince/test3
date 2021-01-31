defmodule T.Support do
  alias __MODULE__.Message
  alias T.{Repo, Matches}
  import Ecto.Query

  def add_message(user_id, author_id, attrs) do
    %Message{id: Ecto.Bigflake.UUID.autogenerate(), author_id: author_id, user_id: user_id}
    |> Matches.message_changeset(attrs)
    |> Repo.insert()
  end

  def list_messages(user_id, opts \\ []) do
    # dir = opts[:dir] || :asc
    # limit = ensure_valid_limit(opts[:limit]) || 20

    q =
      Message
      |> where(user_id: ^user_id)
      |> order_by([m], asc: m.id)

    # |> limit(^limit)
    # |> paginate(opts)
    # |> Repo.all()

    q =
      if after_id = opts[:after] do
        where(q, [m], m.id > ^after_id)
      else
        q
      end

    Repo.all(q)
  end
end
