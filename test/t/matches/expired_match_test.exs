defmodule T.Matches.ExpiredMatchTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.{Matches, Calls}

  describe "expiration_list_expired_matches/0,1" do
    test "doesn't list matches with calls" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      match_event(match: match, event: "call_start")

      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-01 12:00:01Z]) == []
      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-03 12:00:00Z]) == []
      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-10 12:00:00Z]) == []
    end

    test "doesn't list matches with meeting reports" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      match_event(match: match, event: "meeting_report")

      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-01 12:00:01Z]) == []
      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-03 12:00:00Z]) == []
      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-10 12:00:00Z]) == []
    end
  end

  describe "expiration_list_soon_to_expire/0,1" do
    defp exp_notification_window(match) do
      match.inserted_at
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.add(Matches.match_ttl())
      |> DateTime.add(_24h = -24 * 3600)
    end

    test "sanity check" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      assert exp_notification_window(match) == ~U[2021-01-07 12:00:00Z]
    end

    test "doesn't list matches with calls" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      match_event(match: match, event: "call_start")

      assert Matches.expiration_list_soon_to_expire(exp_notification_window(match)) == []
    end

    test "doesn't list matches with meeting reports" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      match_event(match: match, event: "meeting_report")

      assert Matches.expiration_list_soon_to_expire(exp_notification_window(match)) == []
    end
  end

  describe "expire_match/3" do
    test "deletes voicemail" do
      %{user: u1} = insert(:profile)
      %{user: u2} = insert(:profile)
      %{id: match_id} = insert(:match, user_id_1: u1.id, user_id_2: u2.id)

      {:ok, %Calls.Voicemail{id: v1_id}} =
        Calls.voicemail_save_message(u1.id, match_id, s3_key_1 = Ecto.UUID.generate())

      {:ok, %Calls.Voicemail{id: v2_id}} =
        Calls.voicemail_save_message(u1.id, match_id, s3_key_2 = Ecto.UUID.generate())

      Matches.expire_match(match_id, u1.id, u2.id)

      refute Repo.get(Calls.Voicemail, v1_id)
      refute Repo.get(Calls.Voicemail, v2_id)

      assert [
               %{
                 "bucket" => "pretend-this-is-real",
                 "s3_key" => s3_key_2
               },
               %{
                 "bucket" => "pretend-this-is-real",
                 "s3_key" => s3_key_1
               }
             ] == Enum.map(all_enqueued(worker: T.Media.S3DeleteJob), & &1.args)
    end
  end

  describe "expired match" do
    setup do
      me = onboarded_user(location: moscow_location())
      {:ok, me: me}
    end

    test "matches ought to be expired are deleted from matches and inserted intro expired matches" do
      me = insert(:user)
      not_me = insert(:user)
      long_ago = DateTime.add(DateTime.utc_now(), -8 * 24 * 60 * 60)

      m = insert(:match, user_id_1: me.id, user_id_2: not_me.id, inserted_at: long_ago)
      insert(:match_event, match_id: m.id, event: "created", timestamp: long_ago)

      matches = Matches.Match |> T.Repo.all()
      assert length(matches) == 1

      Matches.expiration_prune()

      matches_after = Matches.Match |> T.Repo.all()
      assert length(matches_after) == 0

      expired_matches = Matches.ExpiredMatch |> T.Repo.all()
      assert length(expired_matches) == 2
    end

    test "recent match is not expired" do
      me = insert(:user)
      not_me = insert(:user)
      long_ago = DateTime.add(DateTime.utc_now(), -2 * 24 * 60 * 58)

      m = insert(:match, user_id_1: me.id, user_id_2: not_me.id, inserted_at: long_ago)
      insert(:match_event, match_id: m.id, event: "created", timestamp: long_ago)

      matches = Matches.Match |> T.Repo.all()
      assert length(matches) == 1

      Matches.expiration_prune()

      matches_after = Matches.Match |> T.Repo.all()
      assert length(matches_after) == 1

      expired_matches = Matches.ExpiredMatch |> T.Repo.all()
      assert length(expired_matches) == 0
    end

    test "match with call is not expired" do
      me = insert(:user)
      not_me = insert(:user)
      long_ago = DateTime.add(DateTime.utc_now(), -3 * 24 * 60 * 60)

      m = insert(:match, user_id_1: me.id, user_id_2: not_me.id, inserted_at: long_ago)
      insert(:match_event, match_id: m.id, event: "created", timestamp: long_ago)
      insert(:match_event, match_id: m.id, event: "call_start", timestamp: long_ago)

      matches = Matches.Match |> T.Repo.all()
      assert length(matches) == 1

      Matches.expiration_prune()

      matches_after = Matches.Match |> T.Repo.all()
      assert length(matches_after) == 1

      expired_matches = Matches.ExpiredMatch |> T.Repo.all()
      assert length(expired_matches) == 0
    end

    test "push notification is scheduled for soon to be expired match" do
      me = insert(:user)
      not_me = insert(:user)
      long_ago = DateTime.add(DateTime.utc_now(), -6 * 24 * 60 * 60 - 30)

      m = insert(:match, user_id_1: me.id, user_id_2: not_me.id, inserted_at: long_ago)
      insert(:match_event, match_id: m.id, event: "created", timestamp: long_ago)

      matches = Matches.Match |> T.Repo.all()
      assert length(matches) == 1

      Matches.expiration_notify_soon_to_expire()

      match_id = m.id

      assert [
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "type" => "match_about_to_expire"
                 }
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)
    end
  end

  defp match(opts) do
    me = insert(:profile)
    mate = insert(:profile)

    insert(:match, user_id_1: me.user_id, user_id_2: mate.user_id, inserted_at: opts[:inserted_at])
  end

  defp match_event(opts) do
    match = opts[:match] || raise "need :match"

    insert(:match_event,
      match_id: match.id,
      event: opts[:event],
      timestamp: opts[:timestamp] || DateTime.truncate(DateTime.utc_now(), :second)
    )
  end
end
