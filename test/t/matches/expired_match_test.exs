defmodule T.Matches.ExpiredMatchTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.Matches

  describe "expired match" do
    setup do
      me = onboarded_user(location: moscow_location())
      {:ok, me: me}
    end

    test "matches ought to be expired are deleted from matches and inserted intro expired matches" do
      me = insert(:user)
      not_me = insert(:user)
      long_ago = DateTime.add(DateTime.utc_now(), -3 * 24 * 60 * 60)

      m = insert(:match, user_id_1: me.id, user_id_2: not_me.id, inserted_at: long_ago)
      insert(:match_event, match_id: m.id, event: "created", timestamp: long_ago)

      matches = Matches.Match |> T.Repo.all()
      assert length(matches) == 1

      Matches.match_expired_check()

      matches_after = Matches.Match |> T.Repo.all()
      assert length(matches_after) == 0

      expired_matches = Matches.ExpiredMatch |> T.Repo.all()
      assert length(expired_matches) == 2
    end

    test "recent match is not expired" do
      me = insert(:user)
      not_me = insert(:user)
      long_ago = DateTime.add(DateTime.utc_now(), -3 * 24 * 60 * 60)
      recently = DateTime.add(DateTime.utc_now(), -5 * 60 * 60)

      m = insert(:match, user_id_1: me.id, user_id_2: not_me.id, inserted_at: long_ago)
      insert(:match_event, match_id: m.id, event: "created", timestamp: long_ago)
      insert(:match_event, match_id: m.id, event: "keep_alive", timestamp: recently)

      matches = Matches.Match |> T.Repo.all()
      assert length(matches) == 1

      Matches.match_expired_check()

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

      Matches.match_expired_check()

      matches_after = Matches.Match |> T.Repo.all()
      assert length(matches_after) == 1

      expired_matches = Matches.ExpiredMatch |> T.Repo.all()
      assert length(expired_matches) == 0
    end

    test "push notification is scheduled for soon to be expired match" do
      me = insert(:user)
      not_me = insert(:user)
      long_ago = DateTime.add(DateTime.utc_now(), -46 * 60 * 60 - 30)

      m = insert(:match, user_id_1: me.id, user_id_2: not_me.id, inserted_at: long_ago)
      insert(:match_event, match_id: m.id, event: "created", timestamp: long_ago)

      matches = Matches.Match |> T.Repo.all()
      assert length(matches) == 1

      Matches.match_soon_to_expire_check()

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

    test "call is not the latest event" do
      me = insert(:user)
      not_me = insert(:user)
      long_ago = DateTime.add(DateTime.utc_now(), -3 * 24 * 60 * 60)
      longer_ago = DateTime.add(DateTime.utc_now(), -5 * 24 * 60 * 60)

      m = insert(:match, user_id_1: me.id, user_id_2: not_me.id, inserted_at: long_ago)
      insert(:match_event, match_id: m.id, event: "saving slot", timestamp: long_ago)
      insert(:match_event, match_id: m.id, event: "call_start", timestamp: longer_ago)

      matches = Matches.Match |> T.Repo.all()
      assert length(matches) == 1

      Matches.match_expired_check()

      matches_after = Matches.Match |> T.Repo.all()
      assert length(matches_after) == 1

      expired_matches = Matches.ExpiredMatch |> T.Repo.all()
      assert length(expired_matches) == 0
    end
  end
end
