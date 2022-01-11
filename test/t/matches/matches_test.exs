defmodule T.MatchesTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: Repo

  alias T.{Matches, Feeds, Calls, PushNotifications.DispatchJob}
  alias T.Feeds.FeedProfile
  alias T.Calls.{Call, Voicemail}
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
        assert {:ok, %{match: nil}} = Matches.like_user(p1_id, p2_id)

        # TODO why do we get matched message?
        # refute_receive _anything, 1
      end)

      assert_receive {Matches, :liked, like}
      assert like == %{by_user_id: p1_id}

      assert [%Like{by_user_id: ^p1_id, user_id: ^p2_id}] = list_likes_for(p2_id)

      assert {:ok, %{match: %Match{id: match_id}}} = Matches.like_user(p2_id, p1_id)

      # for p1
      assert_receive {Matches, :matched, %{id: ^match_id, mate: ^p2_id, audio_only: false}}

      assert [%Match{id: ^match_id, profile: %FeedProfile{user_id: ^p2_id}}] =
               Matches.list_matches(p1_id)

      assert [%Match{id: ^match_id, profile: %FeedProfile{user_id: ^p1_id}}] =
               Matches.list_matches(p2_id)

      spawn(fn ->
        Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
        assert true == Matches.unmatch_match(p1_id, match_id)
      end)

      # for p1
      assert_receive {Matches, :unmatched, ^match_id}
      # for p2
      assert_receive {Matches, :unmatched, ^match_id}

      assert [] == Matches.list_matches(p1_id)
      assert [] == Matches.list_matches(p2_id)

      assert [] == list_likes_for(p1_id)
      assert [] == list_likes_for(p2_id)

      expected = [
        %{"by_user_id" => p1_id, "type" => "invite", "user_id" => p2_id},
        %{"match_id" => match_id, "type" => "match"}
      ]

      actual = Enum.map(all_enqueued(worker: DispatchJob), fn job -> job.args end)

      assert_lists_equal(expected, actual)
    end

    test "deletes voicemail" do
      %{user: u1} = insert(:profile)
      %{user: u2} = insert(:profile)
      %{id: match_id} = insert(:match, user_id_1: u1.id, user_id_2: u2.id)

      {:ok, %Calls.Voicemail{id: v1_id}} =
        Calls.voicemail_save_message(u1.id, match_id, s3_key_1 = Ecto.UUID.generate())

      {:ok, %Calls.Voicemail{id: v2_id}} =
        Calls.voicemail_save_message(u1.id, match_id, s3_key_2 = Ecto.UUID.generate())

      Matches.unmatch_match(u1.id, match_id)

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

  describe "unmatch_with_user/2" do
    test "deletes voicemail" do
      %{user: u1} = insert(:profile)
      %{user: u2} = insert(:profile)
      %{id: match_id} = insert(:match, user_id_1: u1.id, user_id_2: u2.id)

      {:ok, %Calls.Voicemail{id: v1_id}} =
        Calls.voicemail_save_message(u1.id, match_id, s3_key_1 = Ecto.UUID.generate())

      {:ok, %Calls.Voicemail{id: v2_id}} =
        Calls.voicemail_save_message(u1.id, match_id, s3_key_2 = Ecto.UUID.generate())

      Matches.unmatch_with_user(u1.id, u2.id)

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

  describe "like/2" do
    test "bump like count, like ratio" do
      [%{user_id: liked}, %{user_id: liker1}, %{user_id: liker2}, %{user_id: liker3}] =
        insert_list(4, :profile, hidden?: false)

      Matches.like_user(liker1, liked)

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

      Matches.like_user(liker3, liked)

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

  describe "maybe_match_after_end_call/1" do
    defp successful_call(caller_id, called_id) do
      %Call{
        caller_id: caller_id,
        called_id: called_id,
        accepted_at: ~U[2021-12-29 11:08:18Z],
        ended_at: ~U[2021-12-29 11:12:22Z]
      }
    end

    test "creates a match when users haven't been matched yet and call was successful" do
      u1 = onboarded_user()
      u2 = onboarded_user()
      call = successful_call(u1.id, u2.id)

      assert %Match{} = match = Matches.maybe_match_after_end_call(call)

      assert match.user_id_1 == u1.id
      assert match.user_id_2 == u2.id
    end

    test "no-op when users are already matched" do
      u1 = onboarded_user()
      u2 = onboarded_user()

      {:ok, %{match: nil}} = Matches.like_user(u1.id, u2.id)
      {:ok, %{match: %Match{}}} = Matches.like_user(u2.id, u1.id)

      call = successful_call(u1.id, u2.id)
      refute Matches.maybe_match_after_end_call(call)
    end

    test "no-op on calls <1 minute in duration" do
      short_call = %Call{
        accepted_at: ~U[2021-12-29 11:08:18Z],
        ended_at: ~U[2021-12-29 11:09:17Z]
      }

      refute Matches.maybe_match_after_end_call(short_call)
    end

    test "no-op on unanswered calls" do
      unanswered_call = %Call{
        accepted_at: nil,
        ended_at: ~U[2021-12-29 11:09:17Z]
      }

      refute Matches.maybe_match_after_end_call(unanswered_call)
    end
  end

  describe "list_matches/1" do
    setup do
      p1 = insert(:profile)
      p2 = insert(:profile)
      match = insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)
      {:ok, profiles: [p1, p2], match: match}
    end

    test "can list multiple voicemail messages", ctx do
      %{profiles: [%{user_id: u1_id}, %{user_id: u2_id}], match: %{id: match_id}} = ctx

      {:ok, %Voicemail{} = v1} =
        Calls.voicemail_save_message(
          u1_id,
          match_id,
          _s3_key = "4f5509bd-b26a-45c0-b858-6f48172678d5"
        )

      {:ok, %Voicemail{} = v2} =
        Calls.voicemail_save_message(
          u1_id,
          match_id,
          _s3_key = "79c3a8d1-e8b6-4517-a8f2-311d90afaf70"
        )

      # both me and mate receive current voicemail in interaction, no matter who left it
      assert [%Match{id: ^match_id, voicemail: voicemail}] = Matches.list_matches(u1_id)
      assert [%Match{id: ^match_id, voicemail: ^voicemail}] = Matches.list_matches(u2_id)
      assert_lists_equal(voicemail, [v1, v2])
    end

    test "matches with calls don't have expiration date", ctx do
      %{profiles: [%{user_id: u1_id}, %{user_id: u2_id}], match: %{id: match_id}} = ctx
      insert(:match_event, match_id: match_id, timestamp: DateTime.utc_now(), event: "call_start")

      assert [%Match{id: ^match_id, expiration_date: nil}] = Matches.list_matches(u1_id)
      assert [%Match{id: ^match_id, expiration_date: nil}] = Matches.list_matches(u2_id)
    end

    test "matches with meeting report don't have expiration date", ctx do
      %{profiles: [%{user_id: u1_id}, %{user_id: u2_id}], match: %{id: match_id}} = ctx

      insert(:match_event,
        match_id: match_id,
        timestamp: DateTime.utc_now(),
        event: "meeting_report"
      )

      assert [%Match{id: ^match_id, expiration_date: nil}] = Matches.list_matches(u1_id)
      assert [%Match{id: ^match_id, expiration_date: nil}] = Matches.list_matches(u2_id)
    end

    test "matches w/o full voicemail exchange have expiration date = inserted_at + 48h", ctx do
      %{
        profiles: [%{user_id: u1_id}, %{user_id: u2_id}],
        match: %{id: match_id, inserted_at: inserted_at}
      } = ctx

      expected_expiration_date =
        inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.add(_48_hours = 2 * 24 * 3600)

      assert [%Match{id: ^match_id, expiration_date: ^expected_expiration_date}] =
               Matches.list_matches(u1_id)

      assert [%Match{id: ^match_id, expiration_date: ^expected_expiration_date}] =
               Matches.list_matches(u2_id)

      # incomplete (one-way) voicemail exchange doesn't change the expiration date

      {:ok, _voicemail} =
        Calls.voicemail_save_message(u1_id, match_id, _s3_key = Ecto.UUID.generate())

      assert [%Match{id: ^match_id, expiration_date: ^expected_expiration_date}] =
               Matches.list_matches(u1_id)

      assert [%Match{id: ^match_id, expiration_date: ^expected_expiration_date}] =
               Matches.list_matches(u2_id)
    end

    test "matches w/ full voicemail exchange have expiration date = inserted_at + 7 * 24h", ctx do
      %{
        profiles: [%{user_id: u1_id}, %{user_id: u2_id}],
        match: %{id: match_id, inserted_at: inserted_at}
      } = ctx

      {:ok, _voicemail} =
        Calls.voicemail_save_message(u1_id, match_id, _s3_key = Ecto.UUID.generate())

      {:ok, _voicemail} =
        Calls.voicemail_save_message(u2_id, match_id, _s3_key = Ecto.UUID.generate())

      expected_expiration_date =
        inserted_at |> DateTime.from_naive!("Etc/UTC") |> DateTime.add(_7_days = 7 * 24 * 3600)

      assert [%Match{id: ^match_id, expiration_date: ^expected_expiration_date}] =
               Matches.list_matches(u1_id)

      assert [%Match{id: ^match_id, expiration_date: ^expected_expiration_date}] =
               Matches.list_matches(u2_id)
    end
  end

  defp list_likes_for(user_id) do
    Like
    |> where(user_id: ^user_id)
    |> Repo.all()
  end
end
