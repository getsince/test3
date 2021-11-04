defmodule T.Matches.ExpiredMatchTest do
  use T.DataCase, async: true

  alias T.Matches

  describe "expired match" do
    setup do
      me = onboarded_user(location: moscow_location())
      {:ok, me: me}
    end

    test "matches ought to be expired are expired" do
      me = insert(:user)
      not_me = insert(:user)
      long_ago = DateTime.add(DateTime.utc_now(), -3 * 24 * 60 * 60)

      m = insert(:match, user_id_1: me.id, user_id_2: not_me.id, inserted_at: long_ago)
      insert(:match_event, match_id: m.id, event: "created", timestamp: long_ago)

      matches =
        Matches.Match
        |> T.Repo.all()

      assert length(matches) == 1

      Matches.match_expired_check()

      matches_after =
        Matches.Match
        |> T.Repo.all()

      assert length(matches_after) == 0

      expired_matches = Matches.ExpiredMatch |> T.Repo.all()

      assert length(expired_matches) == 2
    end
  end
end
