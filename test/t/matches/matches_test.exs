defmodule T.MatchesTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: Repo

  alias T.{Matches, Feeds, PushNotifications.DispatchJob}
  alias T.Feeds.FeedProfile
  alias T.Matches.{Match, Like}

  describe "unmatch_match/2" do
    test "match no longer, likes no longer, unmatched broadcasted" do
      [%{user_id: p1_id}, %{user_id: p2_id}] = insert_list(2, :profile, hidden?: false)

      Matches.subscribe_for_user(p1_id)
      Matches.subscribe_for_user(p2_id)

      parent = self()

      spawn(fn ->
        Matches.subscribe_for_user(p1_id)
        Matches.subscribe_for_user(p2_id)

        Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
        assert {:ok, %{match: nil}} = Matches.like_user(p1_id, p2_id, default_location())

        # TODO why do we get matched message?
        # refute_receive _anything, 1
      end)

      assert_receive {Matches, :liked, like}
      assert like == %{by_user_id: p1_id}

      assert [%Like{by_user_id: ^p1_id, user_id: ^p2_id}] = list_likes_for(p2_id)

      assert {:ok, %{match: %Match{id: match_id}}} =
               Matches.like_user(p2_id, p1_id, default_location())

      # for p1
      assert_receive {Matches, :matched, %{id: ^match_id, mate: ^p2_id}}

      assert [%Match{id: ^match_id, profile: %FeedProfile{user_id: ^p2_id}}] =
               Matches.list_matches(p1_id, default_location())

      assert [%Match{id: ^match_id, profile: %FeedProfile{user_id: ^p1_id}}] =
               Matches.list_matches(p2_id, default_location())

      spawn(fn ->
        Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
        assert true == Matches.unmatch_match(p1_id, match_id)
      end)

      # for p1
      assert_receive {Matches, :unmatched, ^match_id}
      # for p2
      assert_receive {Matches, :unmatched, ^match_id}

      assert [] == Matches.list_matches(p1_id, default_location())
      assert [] == Matches.list_matches(p2_id, default_location())

      assert [] == list_likes_for(p1_id)
      assert [] == list_likes_for(p2_id)

      expected = [
        %{"by_user_id" => p1_id, "type" => "invite", "user_id" => p2_id},
        %{"match_id" => match_id, "type" => "match"},
        %{"match_id" => match_id, "type" => "match_about_to_expire"}
      ]

      actual = Enum.map(all_enqueued(worker: DispatchJob), fn job -> job.args end)

      assert_lists_equal(expected, actual)
    end
  end

  describe "like/2" do
    test "bump like count, like ratio" do
      [%{user_id: liked}, %{user_id: liker1}, %{user_id: liker2}, %{user_id: liker3}] =
        insert_list(4, :profile, hidden?: false)

      Matches.like_user(liker1, liked, default_location())

      assert FeedProfile
             |> where(user_id: ^liked)
             |> select([p], {p.times_liked, p.like_ratio})
             |> Repo.one!() == {1, 1.0}

      Feeds.mark_profile_seen(liked, by: liker1)

      Feeds.mark_profile_seen(liked, by: liker2)

      assert FeedProfile
             |> where(user_id: ^liked)
             |> select([p], {p.times_liked, p.like_ratio})
             |> Repo.one!() == {1, 0.5}

      Matches.like_user(liker3, liked, default_location())

      assert FeedProfile
             |> where(user_id: ^liked)
             |> select([p], {p.times_liked, p.like_ratio})
             |> Repo.one!() == {2, 0.6666666666666666}

      Feeds.mark_profile_seen(liked, by: liker2)

      assert FeedProfile
             |> where(user_id: ^liked)
             |> select([p], {p.times_liked, p.like_ratio})
             |> Repo.one!() == {2, 0.6666666666666666}
    end
  end

  describe "mark_like_seen/2" do
    test "sets like.seen = true" do
      me = onboarded_user()
      liker = onboarded_user()

      {:ok, _} = Matches.like_user(liker.id, me.id, default_location())

      assert %Like{seen: false} =
               Like |> where(by_user_id: ^liker.id) |> where(user_id: ^me.id) |> Repo.one!()

      :ok = Matches.mark_like_seen(me.id, liker.id)

      assert %Like{seen: true} =
               Like |> where(by_user_id: ^liker.id) |> where(user_id: ^me.id) |> Repo.one!()
    end
  end

  describe "list_matches/2" do
    setup do
      p1 = insert(:profile)
      p2 = insert(:profile)
      match = insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)
      {:ok, profiles: [p1, p2], match: match}
    end

    test "matches with calls don't have expiration date", ctx do
      %{profiles: [%{user_id: u1_id}, %{user_id: u2_id}], match: %{id: match_id}} = ctx
      insert(:match_event, match_id: match_id, timestamp: DateTime.utc_now(), event: "call_start")

      assert [%Match{id: ^match_id, expiration_date: nil}] =
               Matches.list_matches(u1_id, default_location())

      assert [%Match{id: ^match_id, expiration_date: nil}] =
               Matches.list_matches(u2_id, default_location())
    end

    test "matches with contact offer don't have expiration date", ctx do
      %{profiles: [%{user_id: u1_id}, %{user_id: u2_id}], match: %{id: match_id}} = ctx

      insert(:match_event,
        match_id: match_id,
        timestamp: DateTime.utc_now(),
        event: "contact_offer"
      )

      assert [%Match{id: ^match_id, expiration_date: nil}] =
               Matches.list_matches(u1_id, default_location())

      assert [%Match{id: ^match_id, expiration_date: nil}] =
               Matches.list_matches(u2_id, default_location())
    end

    test "matches with contact clicks don't have expiration date", ctx do
      %{profiles: [%{user_id: u1_id}, %{user_id: u2_id}], match: %{id: match_id}} = ctx

      insert(:match_event,
        match_id: match_id,
        timestamp: DateTime.utc_now(),
        event: "contact_click"
      )

      assert [%Match{id: ^match_id, expiration_date: nil}] =
               Matches.list_matches(u1_id, default_location())

      assert [%Match{id: ^match_id, expiration_date: nil}] =
               Matches.list_matches(u2_id, default_location())
    end

    test "matches have expiration date = inserted_at + 24h", ctx do
      %{
        profiles: [%{user_id: u1_id}, %{user_id: u2_id}],
        match: %{id: match_id, inserted_at: inserted_at}
      } = ctx

      expected_expiration_date =
        inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.add(_1_day = 1 * 24 * 3600)

      assert [%Match{id: ^match_id, expiration_date: ^expected_expiration_date}] =
               Matches.list_matches(u1_id, default_location())

      assert [%Match{id: ^match_id, expiration_date: ^expected_expiration_date}] =
               Matches.list_matches(u2_id, default_location())
    end

    test "with seen matches", ctx do
      %{
        profiles: [%{user_id: u1_id}, %{user_id: u2_id}],
        match: %{id: match_id}
      } = ctx

      assert [%Match{id: ^match_id, seen: false}] =
               Matches.list_matches(u1_id, default_location())

      assert [%Match{id: ^match_id, seen: false}] =
               Matches.list_matches(u2_id, default_location())

      :ok = Matches.mark_match_seen(u1_id, match_id)

      assert [%Match{id: ^match_id, seen: true}] = Matches.list_matches(u1_id, default_location())

      assert [%Match{id: ^match_id, seen: false}] =
               Matches.list_matches(u2_id, default_location())

      :ok = Matches.mark_match_seen(u2_id, match_id)

      assert [%Match{id: ^match_id, seen: true}] = Matches.list_matches(u1_id, default_location())
      assert [%Match{id: ^match_id, seen: true}] = Matches.list_matches(u2_id, default_location())
    end
  end

  defp list_likes_for(user_id) do
    Like
    |> where(user_id: ^user_id)
    |> Repo.all()
  end
end
