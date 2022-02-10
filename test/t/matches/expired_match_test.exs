defmodule T.Matches.ExpiredMatchTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo
  alias T.Matches

  describe "expiration_list_soon_to_expire/0,1" do
    defp a_day_before_expiration(match) do
      match.inserted_at
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.add(Matches.match_ttl())
      |> DateTime.add(_24h = -24 * 3600)
    end

    test "lists matches without undying event" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      assert ~U[2021-01-07 12:00:00Z] = dt = a_day_before_expiration(match)
      assert Matches.expiration_list_soon_to_expire(dt) == [match.id]
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

      expired_matches = Matches.ExpiredMatch |> T.Repo.all()
      assert length(expired_matches) == 2
    end

    test "recent match is not expired" do
      me = insert(:user)
      not_me = insert(:user)
      long_ago = DateTime.add(DateTime.utc_now(), -2 * 24 * 60 * 58)

      insert(:match, user_id_1: me.id, user_id_2: not_me.id, inserted_at: long_ago)

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
end
