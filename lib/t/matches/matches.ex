defmodule T.Matches do
  @moduledoc """
  User wants to check if they are in an active match? Do they want to unmatch?
  Or maybe they want to send a message to their match?

  Then this is the palce to add code for it.
  """
  import Ecto.Query
  alias T.{Repo, Media, Accounts}
  alias T.Accounts.Profile
  alias T.Matches.{Match, Message}

  @pubsub T.PubSub
  @topic to_string(__MODULE__)

  defp pubsub_match_topic(match_id) when is_binary(match_id) do
    @topic <> ":" <> match_id
  end

  def subscribe(match_id) do
    Phoenix.PubSub.subscribe(@pubsub, pubsub_match_topic(match_id))
  end

  # defp notify_subscribers({:ok, %Message{match_id: match_id} = message} = success, event)
  #      when is_binary(match_id) do
  #   Phoenix.PubSub.broadcast(@pubsub, pubsub_match_topic(match_id), {__MODULE__, event, message})
  #   success
  # end

  defp notify_subscribers({:error, _reason} = error, _event) do
    error
  end

  defp notify_subscribers({:ok, _changes} = success, [:unmatched, match_id]) do
    Phoenix.PubSub.broadcast(@pubsub, pubsub_match_topic(match_id), {__MODULE__, :unmatched})
    success
  end

  # TODO test can unmatch, unmatches the other user, and that there is a broadcast
  # TODO test profiles are marked unmatched as well
  def unmatch(user_id, match_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:unmatch, fn repo, _changes ->
      Match
      |> where(id: ^match_id)
      |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
      |> where(alive?: true)
      |> update(set: [alive?: false])
      |> select([m], [m.user_id_1, m.user_id_2])
      |> repo.update_all([])
      |> case do
        {1, [user_ids]} -> {:ok, user_ids}
        {0, _} -> {:error, :no_match}
      end
    end)
    |> Ecto.Multi.run(:unhide, fn repo, %{unmatch: user_ids} ->
      Profile
      |> where([p], p.user_id in ^user_ids)
      # TODO what if blocked or deleted?
      |> repo.update_all(set: [hidden?: false])

      {:ok, nil}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _changes} = success -> success
      {:error, :unmatch, reason, _changes} -> {:error, reason}
    end
    |> notify_subscribers([:unmatched, match_id])
  end

  def get_current_match(user_id) do
    Match
    |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
    |> where(alive?: true)
    |> Repo.one()
  end

  def get_other_profile_for_match!(%Match{user_id_1: id1, user_id_2: id2}, user_id) do
    [other_user_id] = [id1, id2] -- [user_id]
    Accounts.get_profile!(other_user_id)
  end

  # TODO check user is match member
  # or use rls
  def add_message(match_id, user_id, attrs) do
    %Message{id: Ecto.Bigflake.UUID.autogenerate(), author_id: user_id, match_id: match_id}
    |> message_changeset(attrs)
    |> Repo.insert()

    # |> notify_subscribers([:message, :create])
  end

  def media_upload_form(content_type) do
    Media.sign_form_upload(
      key: Ecto.UUID.generate(),
      content_type: content_type,
      max_file_size: 8_000_000,
      expires_in: :timer.hours(1)
    )
  end

  def media_s3_url do
    Media.url()
  end

  # TODO rls or auth
  # TODO paginate
  def list_messages(match_id, opts \\ []) do
    # dir = opts[:dir] || :asc
    # limit = ensure_valid_limit(opts[:limit]) || 20

    q =
      Message
      |> where(match_id: ^match_id)
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

  # TODO do it proper
  # defp paginate(query, opts) do
  #   case {opts[:after], opts[:before]} do
  #     {nil, nil} ->
  #       query

  #     {after_timestamp, nil} ->
  #       paginate_after(query, after_timestamp)

  #     {nil, before_timestamp} ->
  #       paginate_before(query, before_timestamp)

  #     {after_timestamp, before_timestamp} ->
  #       query |> paginate_after(after_timestamp) |> paginate_before(before_timestamp)
  #   end
  # end

  # defp paginate_after(query, after_timestamp) do
  #   where(query, [m], m.timestamp >= ^after_timestamp)
  # end

  # defp paginate_before(query, before_timestamp) do
  #   where(query, [m], m.timestamp <= ^before_timestamp)
  # end

  # defp ensure_valid_limit(limit) when is_integer(limit) and limit > 0 and limit <= 100 do
  #   limit
  # end

  # defp ensure_valid_limit(_invalid), do: nil

  import Ecto.Changeset

  @texts ["text", "markdown", "emoji"]
  @media ["audio", "photo", "video"]
  @valid_kinds @texts ++ @media ++ ["location"]

  def message_changeset(changeset, attrs) do
    changeset
    |> cast(attrs, [:kind, :data])
    |> validate_required([:kind, :data])
    |> validate_inclusion(:kind, @valid_kinds)
    |> validate_message_data()
  end

  defp validate_message_data(%Ecto.Changeset{valid?: true} = changeset) do
    case get_field(changeset, :kind) do
      t when t in @texts -> validate_text_message(changeset)
      m when m in @media -> validate_media_message(changeset)
      "location" -> validate_location_message(changeset)
    end
  end

  defp validate_message_data(changeset), do: changeset

  defp validate_text_message(changeset) do
    data = get_field(changeset, :data) || %{}

    %Message.Text{}
    |> cast(data, [:text])
    |> validate_required(:text)
    |> validate_length(:text, min: 1, max: 1000, count: :bytes)
    |> maybe_merge_errors(changeset)
  end

  defp validate_media_message(changeset) do
    data = get_field(changeset, :data) || %{}

    %Message.Media{}
    |> cast(data, [:s3_key])
    |> validate_required(:s3_key)
    |> validate_length(:s3_key, min: 1, max: 100, count: :bytes)
    |> maybe_merge_errors(changeset)
  end

  defp validate_location_message(changeset) do
    data = get_field(changeset, :data) || %{}

    %Message.Location{}
    |> cast(data, [:lat, :lon])
    |> validate_required([:lat, :lon])
    |> maybe_merge_errors(changeset)
  end

  defp maybe_merge_errors(%Ecto.Changeset{valid?: true}, changeset) do
    changeset
  end

  defp maybe_merge_errors(%Ecto.Changeset{valid?: false} = changeset2, changeset1) do
    merge_errors(changeset1, changeset2)
  end

  defp merge_errors(changeset1, changeset2) do
    %Ecto.Changeset{
      changeset1
      | valid?: false,
        errors: Keyword.merge(changeset1.errors, changeset2.errors)
    }
  end
end
