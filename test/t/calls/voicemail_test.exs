defmodule T.Calls.VoicemailTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.{Calls, Matches, Feeds}
  alias T.Calls.Voicemail
  alias T.PushNotifications.{APNSJob, DispatchJob}

  import Mox
  setup :verify_on_exit!

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

    test "success: saves/overwrites voicemail, updates match.exchanged_voicemail" do
      me = onboarded_user()
      mate = onboarded_user()

      match = insert(:match, user_id_1: me.id, user_id_2: mate.id)
      refute match.exchanged_voicemail

      # me -voice> mate
      assert {:ok, %Calls.Voicemail{id: v1_id}, _new_match_expiration_date = nil} =
               Calls.voicemail_save_message(me.id, match.id, _s3_key = Ecto.UUID.generate())

      assert {:ok, %Calls.Voicemail{id: v2_id}, _new_match_expiration_date = nil} =
               Calls.voicemail_save_message(me.id, match.id, _s3_key = Ecto.UUID.generate())

      refute Repo.get(Matches.Match, match.id).exchanged_voicemail

      # these voicemail messages will be overwritten
      voicemail_ids = voicemail_ids(match.id)
      assert_lists_equal(voicemail_ids, [v1_id, v2_id])

      # mate -voice> me
      assert {:ok, %Calls.Voicemail{id: v3_id}, _new_match_expiration_date = %DateTime{}} =
               Calls.voicemail_save_message(mate.id, match.id, _s3_key = Ecto.UUID.generate())

      assert Repo.get(Matches.Match, match.id).exchanged_voicemail

      # voicemail messages from me to mate have been overwritten
      voicemail_ids = voicemail_ids(match.id)
      assert_lists_equal(voicemail_ids, [v3_id])
    end
  end

  describe "voicemail_listen_message/3" do
    test "failure: caller can't listen to their own message" do
      caller = onboarded_user()
      called = onboarded_user()

      match = insert(:match, user_id_1: caller.id, user_id_2: called.id)

      assert {:ok, %Voicemail{} = voicemail, _new_match_expiration_date = nil} =
               Calls.voicemail_save_message(caller.id, match.id, _s3_key = Ecto.UUID.generate())

      refute Calls.voicemail_listen_message(caller.id, voicemail.id)
      assert %Voicemail{listened_at: nil} = Repo.get!(Voicemail, voicemail.id)
    end

    test "failure: user outside of the match can't to listen to their messages" do
      caller = onboarded_user()
      called = onboarded_user()
      spy = onboarded_user()

      match = insert(:match, user_id_1: caller.id, user_id_2: called.id)

      assert {:ok, %Voicemail{} = voicemail, _new_match_expiration_date = nil} =
               Calls.voicemail_save_message(caller.id, match.id, _s3_key = Ecto.UUID.generate())

      refute Calls.voicemail_listen_message(spy.id, voicemail.id)
      assert %Voicemail{listened_at: nil} = Repo.get!(Voicemail, voicemail.id)
    end

    test "failure: can't listen a voicemail that doesn't exist" do
      me = onboarded_user()
      refute Calls.voicemail_listen_message(me.id, Ecto.Bigflake.UUID.generate())
    end

    test "success: sets listened_at" do
      caller = onboarded_user()
      called = onboarded_user()

      match = insert(:match, user_id_1: caller.id, user_id_2: called.id)

      assert {:ok, %Voicemail{} = voicemail, _new_match_expiration_date = nil} =
               Calls.voicemail_save_message(caller.id, match.id, _s3_key = Ecto.UUID.generate())

      refute voicemail.listened_at

      now = DateTime.utc_now()
      assert Calls.voicemail_listen_message(called.id, voicemail.id, now)

      assert %Voicemail{} = listened_voicemail = Repo.get!(Voicemail, voicemail.id)
      assert listened_voicemail.listened_at == DateTime.truncate(now, :second)
    end
  end

  describe "voicemail_delete_all/1" do
    test "deletes all voicemail and schedules deletions from s3" do
      me = onboarded_user()
      mate = onboarded_user()

      {:ok, _} = Matches.like_user(me.id, mate.id)
      {:ok, %{match: %Matches.Match{id: match_id}}} = Matches.like_user(mate.id, me.id)

      {:ok, %Calls.Voicemail{}, _new_match_expiration_date = nil} =
        Calls.voicemail_save_message(
          me.id,
          match_id,
          _s3_key = "37f22461-6678-45f2-8140-b45755471b42"
        )

      {:ok, %Calls.Voicemail{}, _new_match_expiration_date = nil} =
        Calls.voicemail_save_message(
          me.id,
          match_id,
          _s3_key = "4b087c06-652a-46aa-8a15-9b11d4be7f18"
        )

      {:ok, %Calls.Voicemail{}, _new_match_expiration_date = %DateTime{}} =
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
    setup [:with_profiles, :with_match]

    test "push notification is scheduled and delivered to mate", ctx do
      %{
        profiles: [%{user_id: caller_id}, %{user_id: receiver_id, user: receiver}],
        match: %{id: match_id}
      } = ctx

      assert {:ok, %Voicemail{}, _new_match_expiration_date = nil} =
               Calls.voicemail_save_message(
                 caller_id,
                 match_id,
                 _s3_key = Ecto.UUID.generate()
               )

      insert(:apns_device, user: receiver, device_id: Base.decode16!("BABA"))
      insert(:apns_device, user: receiver, device_id: Base.decode16!("ABAB"), locale: "ru")

      # assert dispatch is enqueued
      assert Enum.map(all_enqueued(worker: DispatchJob), & &1.args) == [
               %{
                 "type" => "voicemail_sent",
                 "match_id" => match_id,
                 "caller_id" => caller_id,
                 "receiver_id" => receiver_id
               }
             ]

      assert %{failure: 0, snoozed: 0, success: 1} =
               Oban.drain_queue(queue: :apns, with_safety: false)

      # assert dispatched correctly to apns jobs
      assert [
               %{
                 "data" => %{
                   "gender" => "M",
                   "match_id" => ^match_id,
                   "name" => "Lucifer"
                 },
                 "device_id" => "ABAB",
                 "locale" => "ru",
                 "template" => "voicemail_sent"
               },
               %{
                 "data" => %{
                   "gender" => "M",
                   "match_id" => ^match_id,
                   "name" => "Lucifer"
                 },
                 "device_id" => "BABA",
                 "locale" => "en",
                 "template" => "voicemail_sent"
               }
             ] = Enum.map(all_enqueued(worker: APNSJob), & &1.args)

      # assert apns jobs execute correctly
      expected_alerts = %{
        "BABA" => %{
          "title" => "Lucifer sent you a voice message!",
          "body" => "Come in to view & reply ✨"
        },
        "ABAB" => %{
          "title" => "Lucifer прислал тебe аудио-сообщение!",
          "body" => "Заходи, чтобы просмотреть и ответить ✨"
        }
      }

      expect(MockAPNS, :push, 2, fn %{device_id: device_id, payload: payload} ->
        assert expected_alerts[device_id] == payload["aps"]["alert"]
        :ok
      end)

      assert %{failure: 0, snoozed: 0, success: 2} =
               Oban.drain_queue(queue: :apns, with_safety: false)
    end

    test "voicemail is broadcast via pubsub to mate", ctx do
      %{
        profiles: [%{user_id: me}, %{user_id: mate}],
        match: %{id: match_id, inserted_at: match_inserted_at}
      } = ctx

      Feeds.subscribe_for_user(mate)

      assert {:ok, %Voicemail{} = v1, _new_match_expiration_date = nil} =
               Calls.voicemail_save_message(
                 me,
                 match_id,
                 _s3_key = Ecto.UUID.generate()
               )

      assert_receive {Calls, [:voicemail, :received], %{voicemail: ^v1, expiration_date: nil}}

      Feeds.subscribe_for_user(me)

      expected_expiration_date =
        match_inserted_at
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.add(Matches.match_ttl())

      assert {:ok, %Voicemail{} = v2, ^expected_expiration_date} =
               Calls.voicemail_save_message(
                 mate,
                 match_id,
                 _s3_key = Ecto.UUID.generate()
               )

      assert_receive {Calls, [:voicemail, :received],
                      %{voicemail: ^v2, expiration_date: ^expected_expiration_date}}
    end
  end

  describe "voicemail_save_message/3 for archived match side-effects" do
    setup [:with_profiles, :with_archived_match]

    test "archived match is unarchived", ctx do
      %{profiles: [%{user_id: caller_id}, %{user_id: receiver_id}]} = ctx

      assert [%{match_id: match_id}] = Matches.list_archived_matches(receiver_id)

      assert {:ok, %Voicemail{}, _new_match_expiration_date} =
               Calls.voicemail_save_message(
                 caller_id,
                 match_id,
                 _s3_key = Ecto.UUID.generate()
               )

      assert Matches.list_archived_matches(receiver_id) == []
    end
  end

  defp with_profiles(_context) do
    {:ok, profiles: insert_list(2, :profile, name: "Lucifer", hidden?: false)}
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

  defp voicemail_ids(match_id) do
    Calls.Voicemail |> where(match_id: ^match_id) |> select([v], v.id) |> Repo.all()
  end
end
