defmodule T.Calls do
  @moduledoc false
  import Ecto.Query
  alias Ecto.Multi

  require Logger

  import T.Cluster, only: [primary_rpc: 3]

  alias T.{Repo, Feeds, Matches}
  alias T.Calls.Voicemail
  alias T.Matches.{Match, ArchivedMatch, Interaction}
  alias T.PushNotifications.DispatchJob

  @type uuid :: Ecto.Bigflake.UUID.t()

  alias T.Media

  def voicemail_s3_url do
    Media.user_s3_url()
  end

  def voicemail_url(s3_key) do
    Media.user_presigned_url(s3_key)
  end

  def voicemail_upload_form(content_type) do
    Media.sign_form_upload(
      key: Ecto.UUID.generate(),
      content_type: content_type,
      # 50 MB
      max_file_size: 50_000_000,
      expires_in: :timer.hours(1),
      acl: "private"
    )
  end

  @spec voicemail_save_message(uuid, uuid, uuid) ::
          {:ok, %Voicemail{}} | {:error, reason :: String.t()}
  def voicemail_save_message(caller_id, match_id, s3_key) do
    primary_rpc(__MODULE__, :local_voicemail_save_message, [caller_id, match_id, s3_key])
  end

  @doc false
  def local_voicemail_save_message(caller_id, match_id, s3_key) do
    voicemail = %Voicemail{caller_id: caller_id, match_id: match_id, s3_key: s3_key}

    Multi.new()
    |> Multi.run(:mate, fn _repo, _changes ->
      users =
        Match
        |> where(id: ^match_id)
        |> where([m], m.user_id_1 == ^caller_id or m.user_id_2 == ^caller_id)
        |> select([m], [m.user_id_1, m.user_id_2])
        |> Repo.one()

      if users do
        [mate] = users -- [caller_id]
        {:ok, mate}
      else
        {:error, :not_found}
      end
    end)
    |> Multi.run(:delete_voicemail, fn _repo, %{mate: mate} ->
      # TODO should still be deleted?
      {_, s3_keys} =
        Voicemail
        |> where(match_id: ^match_id)
        |> where(caller_id: ^mate)
        |> select([v], v.s3_key)
        |> Repo.delete_all()

      schedule_s3_delete(s3_keys)

      {:ok, s3_keys}
    end)
    |> Multi.insert(:voicemail, voicemail)
    |> Multi.insert(:interaction, fn %{mate: mate, voicemail: voicemail} ->
      %Interaction{
        id: voicemail.id,
        from_user_id: caller_id,
        to_user_id: mate,
        match_id: match_id,
        data: %{"type" => "voicemail", "s3" => s3_key}
      }
    end)
    |> Oban.insert(:push, fn %{mate: mate} ->
      DispatchJob.new(%{
        "type" => "voicemail_sent",
        "match_id" => match_id,
        "caller_id" => caller_id,
        "receiver_id" => mate
      })
    end)
    |> Multi.delete_all(:unarchive, where(ArchivedMatch, match_id: ^match_id))
    |> Repo.transaction()
    |> case do
      {:ok, %{voicemail: voicemail, interaction: interaction, mate: mate}} ->
        Feeds.broadcast_for_user(mate, {__MODULE__, [:voicemail, :received], voicemail})
        Matches.broadcast_interaction(interaction)
        {:ok, voicemail}

      {:error, :mate, :not_found, _changes} ->
        {:error, "voicemail not allowed"}
    end
  end

  @spec voicemail_listen_message(uuid, uuid, DateTime.t()) :: boolean()
  def voicemail_listen_message(user_id, voicemail_id, now \\ DateTime.utc_now()) do
    listened_at = DateTime.truncate(now, :second)
    primary_rpc(__MODULE__, :local_voicemail_listen_message, [user_id, voicemail_id, listened_at])
  end

  @doc false
  def local_voicemail_listen_message(user_id, voicemail_id, listened_at) do
    {count, _} =
      Voicemail
      |> where(id: ^voicemail_id)
      |> join(:inner, [v], m in Match,
        on: m.id == v.match_id and (m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
      )
      |> where([v], v.caller_id != ^user_id)
      |> where([v, m], v.caller_id == m.user_id_1 or v.caller_id == m.user_id_2)
      |> Repo.update_all(set: [listened_at: listened_at])

    count == 1
  end

  @spec voicemail_delete_all(uuid) :: :ok
  def voicemail_delete_all(match_id) do
    primary_rpc(__MODULE__, :local_voicemail_delete_all, [match_id])
  end

  @doc false
  def local_voicemail_delete_all(match_id) do
    {_count, s3_keys} =
      Voicemail
      |> where(match_id: ^match_id)
      |> select([v], v.s3_key)
      |> Repo.delete_all()

    schedule_s3_delete(s3_keys)

    :ok
  end

  defp schedule_s3_delete(s3_keys) do
    bucket = Media.user_bucket()

    s3_keys
    |> Enum.map(fn s3_key -> Media.S3DeleteJob.new(%{"bucket" => bucket, "s3_key" => s3_key}) end)
    |> Oban.insert_all()
  end
end
