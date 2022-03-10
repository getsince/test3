defmodule T.Matches.ExpiredMatchTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo
  alias T.Matches

  describe "expiration_list_expired_matches/0,1" do
    test "doesn't list matches with contact clicks" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      match_event(match: match, event: "contact_click")

      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-01 12:00:01Z]) == []
      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-03 12:00:00Z]) == []
      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-10 12:00:00Z]) == []
    end
  end

  describe "expiration_list_soon_to_expire/0,1" do
    defp two_hours_before_expiration(match) do
      match.inserted_at
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.add(Matches.match_ttl())
      |> DateTime.add(_2h = -2 * 3600)
    end

    test "lists matches without undying event" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      assert ~U[2021-01-02 10:00:00Z] = dt = two_hours_before_expiration(match)
      assert Matches.expiration_list_soon_to_expire(dt) == [match.id]
    end

    test "doesn't list matches with contact clicks" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      match_event(match: match, event: "contact_click")

      assert Matches.expiration_list_soon_to_expire(two_hours_before_expiration(match)) == []
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

      insert(:match, user_id_1: me.id, user_id_2: not_me.id, inserted_at: long_ago)

      matches = Matches.Match |> T.Repo.all()
      assert length(matches) == 1

      Matches.expiration_prune()

      matches_after = Matches.Match |> T.Repo.all()
      assert length(matches_after) == 0
    end

    test "recent match is not expired" do
      me = insert(:user)
      not_me = insert(:user)
      long_ago = DateTime.add(DateTime.utc_now(), -12 * 60 * 58)

      insert(:match, user_id_1: me.id, user_id_2: not_me.id, inserted_at: long_ago)

      matches = Matches.Match |> T.Repo.all()
      assert length(matches) == 1

      Matches.expiration_prune()

      matches_after = Matches.Match |> T.Repo.all()
      assert length(matches_after) == 1
    end

    test "push notification is scheduled for soon to be expired match" do
      me = insert(:user)
      not_me = insert(:user)
      long_ago = DateTime.add(DateTime.utc_now(), -22 * 60 * 60 - 30)

      m = insert(:match, user_id_1: me.id, user_id_2: not_me.id, inserted_at: long_ago)

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
