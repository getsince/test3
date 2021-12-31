defmodule T.Matches.ExpiredMatchTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.Matches

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

    test "lists matches with no voicemail exchange after two days" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])

      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-03 12:00:00Z]) == []

      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-03 12:00:01Z]) ==
               [%{id: match.id, user_id_1: match.user_id_1, user_id_2: match.user_id_2}]
    end

    test "lists matches with one-sided voicemail exchange after two days" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      voicemail(match: match, caller_id: match.user_id_1)
      voicemail(match: match, caller_id: match.user_id_1)

      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-03 12:00:00Z]) == []

      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-03 12:00:01Z]) ==
               [%{id: match.id, user_id_1: match.user_id_1, user_id_2: match.user_id_2}]
    end

    test "lists matches with voicemail exchange after seven days" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])

      voicemail(match: match, caller_id: match.user_id_1)
      voicemail(match: match, caller_id: match.user_id_1)
      voicemail(match: match, caller_id: match.user_id_2)

      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-08 12:00:00Z]) == []

      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-08 12:00:01Z]) ==
               [%{id: match.id, user_id_1: match.user_id_1, user_id_2: match.user_id_2}]
    end
  end

  describe "expiration_list_soon_to_expire/0,1" do
    defp in_pre_voicemail_exp_notification_window(match) do
      match.inserted_at
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.add(Matches.pre_voicemail_ttl())
      |> DateTime.add(_3h = -3 * 3600)
    end

    defp in_post_voicemail_exp_notification_window(match) do
      match.inserted_at
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.add(Matches.match_ttl())
      |> DateTime.add(_24h = -24 * 3600)
    end

    test "sanity check" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      assert in_pre_voicemail_exp_notification_window(match) == ~U[2021-01-03 09:00:00Z]
      assert in_post_voicemail_exp_notification_window(match) == ~U[2021-01-07 12:00:00Z]
    end

    test "doesn't list matches with calls" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      match_event(match: match, event: "call_start")

      assert Matches.expiration_list_soon_to_expire(
               in_pre_voicemail_exp_notification_window(match)
             ) == []

      assert Matches.expiration_list_soon_to_expire(
               in_post_voicemail_exp_notification_window(match)
             ) == []
    end

    test "doesn't list matches with meeting reports" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      match_event(match: match, event: "meeting_report")

      assert Matches.expiration_list_soon_to_expire(
               in_pre_voicemail_exp_notification_window(match)
             ) == []

      assert Matches.expiration_list_soon_to_expire(
               in_post_voicemail_exp_notification_window(match)
             ) == []
    end

    test "lists matches with no voicemail exchange" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])

      assert Matches.expiration_list_soon_to_expire(
               in_pre_voicemail_exp_notification_window(match)
             ) == [match.id]
    end

    test "lists matches with one-sided voicemail exchange" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      voicemail(match: match, caller_id: match.user_id_1)
      voicemail(match: match, caller_id: match.user_id_1)

      assert Matches.expiration_list_soon_to_expire(
               in_pre_voicemail_exp_notification_window(match)
             ) == [match.id]
    end

    test "lists matches with voicemail exchange" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])

      voicemail(match: match, caller_id: match.user_id_1)
      voicemail(match: match, caller_id: match.user_id_1)
      voicemail(match: match, caller_id: match.user_id_2)

      assert Matches.expiration_list_soon_to_expire(
               in_pre_voicemail_exp_notification_window(match)
             ) == []

      assert Matches.expiration_list_soon_to_expire(
               in_post_voicemail_exp_notification_window(match)
             ) == [match.id]
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
      long_ago = DateTime.add(DateTime.utc_now(), -2 * 24 * 60 * 60)

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

  defp voicemail(opts) do
    insert(:voicemail,
      match: opts[:match],
      caller_id: opts[:caller_id],
      s3_key: Ecto.UUID.generate()
    )
  end
end
