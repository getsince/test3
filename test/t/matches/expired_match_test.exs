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

    test "doesn't list matches with contact offers" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      match_event(match: match, event: "contact_offer")

      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-01 12:00:01Z]) == []
      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-03 12:00:00Z]) == []
      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-10 12:00:00Z]) == []
    end

    test "doesn't list matches with contact clicks" do
      match = match(inserted_at: ~N[2021-01-01 12:00:00])
      match_event(match: match, event: "contact_click")

      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-01 12:00:01Z]) == []
      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-03 12:00:00Z]) == []
      assert Matches.expiration_list_expired_matches(_at = ~U[2021-01-10 12:00:00Z]) == []
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
      long_ago = DateTime.add(DateTime.utc_now(), -12 * 60 * 58)

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
