defmodule T.Calls.VoicemailTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.{Calls, Matches, Feeds}
  alias T.Calls.Voicemail

  describe "voicemail_save_message/3" do
    test "failure: when not in match" do
      caller_id = Ecto.Bigflake.UUID.generate()
      match_id = Ecto.Bigflake.UUID.generate()
      s3_key = Ecto.UUID.generate()

      assert {:error, "voicemail not allowed"} =
               Calls.voicemail_save_message(caller_id, match_id, s3_key)

      # with real caller
      caller = onboarded_user()

      assert {:error, "voicemail not allowed"} =
               Calls.voicemail_save_message(caller.id, match_id, s3_key)

      # with real match caller is not part of
      match = insert(:match, user_id_1: insert(:user).id, user_id_2: insert(:user).id)

      assert {:error, "voicemail not allowed"} =
               Calls.voicemail_save_message(caller.id, match.id, s3_key)
    end

    test "success: saves voicemail and updates match.exchanged_voicemail" do
      me = onboarded_user()
      mate = onboarded_user()

      match = insert(:match, user_id_1: me.id, user_id_2: mate.id)
      refute match.exchanged_voicemail

      # me -voice> mate

      assert {:ok, %Calls.Voicemail{}} =
               Calls.voicemail_save_message(me.id, match.id, _s3_key = Ecto.UUID.generate())

      refute Repo.get(Matches.Match, match.id).exchanged_voicemail

      # mate -voice> me

      assert {:ok, %Calls.Voicemail{}} =
               Calls.voicemail_save_message(mate.id, match.id, _s3_key = Ecto.UUID.generate())

      assert Repo.get(Matches.Match, match.id).exchanged_voicemail
    end

    test "success: deletes voicemail from mate"
  end

  describe "voicemail_delete_all/1" do
    test "deletes all voicemail and schedules deletions from s3" do
      me = onboarded_user()
      mate = onboarded_user()

      {:ok, _} = Matches.like_user(me.id, mate.id)
      {:ok, %{match: %Matches.Match{id: match_id}}} = Matches.like_user(mate.id, me.id)

      {:ok, %Calls.Voicemail{}} =
        Calls.voicemail_save_message(
          me.id,
          match_id,
          _s3_key = "37f22461-6678-45f2-8140-b45755471b42"
        )

      {:ok, %Calls.Voicemail{}} =
        Calls.voicemail_save_message(
          me.id,
          match_id,
          _s3_key = "4b087c06-652a-46aa-8a15-9b11d4be7f18"
        )

      {:ok, %Calls.Voicemail{}} =
        Calls.voicemail_save_message(
          mate.id,
          match_id,
          _s3_key = "6e0deeb2-1c06-4d9f-99fb-34b8f2dc8721"
        )

      :ok = Calls.voicemail_delete_all(match_id)

      # verify all DB entries have been deleted
      refute Calls.Voicemail |> where(match_id: ^match_id) |> Repo.exists?()

      # verify oban jobs to delete S3 objects have been scheduled
      assert [
               %{
                 "bucket" => "pretend-this-is-real",
                 "s3_key" => "6e0deeb2-1c06-4d9f-99fb-34b8f2dc8721"
               },
               %{
                 "bucket" => "pretend-this-is-real",
                 "s3_key" => "4b087c06-652a-46aa-8a15-9b11d4be7f18"
               },
               %{
                 "bucket" => "pretend-this-is-real",
                 "s3_key" => "37f22461-6678-45f2-8140-b45755471b42"
               }
             ] == all_enqueued(worker: T.Media.S3DeleteJob) |> Enum.map(& &1.args)
    end
  end

  describe "voicemail_save_message/3 side-effects" do
    setup [:with_profiles]

    setup %{profiles: [_p1, p2]} do
      Feeds.subscribe_for_user(p2.user_id)
    end

    setup [:with_match, :with_voicemail]

    test "push notification is scheduled for mate", ctx do
      %{
        profiles: [%{user_id: caller_id}, %{user_id: receiver_id}],
        match: %{id: match_id}
      } = ctx

      assert [
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "receiver_id" => ^receiver_id,
                   "caller_id" => ^caller_id,
                   "type" => "voicemail_sent"
                 }
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)
    end

    test "offer is broadcast via pubsub to mate", ctx do
      %{
        profiles: [_p1, %{user_id: _receiver_id}],
        voicemail: %{s3_key: s3_key}
      } = ctx

      assert_receive {Calls, [:voicemail, :received], %Voicemail{} = voicemail}
      assert voicemail.s3_key == s3_key
      # TODO caller_id
    end
  end

  describe "save_contact_offer/3 for archived match side-effects" do
    setup [:with_profiles]

    setup %{profiles: [_p1, p2]} do
      Feeds.subscribe_for_user(p2.user_id)
    end

    setup [:with_archived_match, :with_voicemail]

    test "archived match is unarchived", ctx do
      %{
        profiles: [_p1, %{user_id: receiver_id}],
        voicemail: %{s3_key: s3_key}
      } = ctx

      assert_receive {Calls, [:voicemail, :received], %Voicemail{} = voicemail}
      assert voicemail.s3_key == s3_key
      # TODO caller_id

      assert Matches.list_archived_matches(receiver_id) == []
    end
  end

  defp with_profiles(_context) do
    {:ok, profiles: insert_list(2, :profile, hidden?: false)}
  end

  defp with_match(%{profiles: [p1, p2]}) do
    {:ok, match: insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)}
  end

  defp with_archived_match(%{profiles: [p1, p2]}) do
    match = insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)
    Matches.mark_match_archived(match.id, p2.user_id)
    assert [_] = Matches.list_archived_matches(p2.user_id)
    {:ok, match: match}
  end

  defp with_voicemail(%{profiles: [p1, _p2], match: match}) do
    assert {:ok, %Voicemail{} = voicemail} =
             Calls.voicemail_save_message(
               p1.user_id,
               match.id,
               _s3_key = Ecto.UUID.generate()
             )

    {:ok, voicemail: voicemail}
  end
end
