defmodule T.Calls.VoicemailTest do
  use T.DataCase
  use Oban.Testing, repo: T.Repo

  alias T.Calls
  alias T.Calls.Voicemail
  alias T.Matches

  describe "voicemail_save_message/3 for invalid match" do
    setup [:with_profiles]

    # @s3_key "f2cb52d1-423e-4fd9-be7c-24287e0d977c"

    # TODO
    # test "with non-existent match", %{profiles: [p1, _]} do
    #   match = Ecto.UUID.generate()

    #   assert_raise Ecto.NoResultsError, fn ->
    #     Calls.voicemail_save_message(p1.user_id, match, @s3_key)
    #   end
    # end

    # TODO
    # test "with match we are not part of", %{profiles: [p1, p2]} do
    #   p3 = insert(:profile, hidden?: false)
    #   match = insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)

    #   assert_raise Ecto.NoResultsError, fn ->
    #     Calls.voicemail_save_message(p3.user_id, match.id, @s3_key)
    #   end

    #   match_event = Matches.MatchEvent |> T.Repo.all()

    #   assert length(match_event) == 0
    # end
  end

  describe "voicemail_save_message/3" do
    setup [:with_profiles, :with_match]

    # TODO empty s3key
    # TODO multiple voicemails
  end

  describe "voicemail_save_message/3 side-effects" do
    setup [:with_profiles]

    setup %{profiles: [_p1, p2]} do
      Calls.subscribe_for_user(p2.user_id)
    end

    setup [:with_match, :with_voicemail]

    test "push notification is scheduled for mate", %{
      profiles: [%{user_id: caller_id}, %{user_id: receiver_id}],
      match: %{id: match_id}
    } do
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

    test "offer is broadcast via pubsub to mate", %{
      profiles: [_p1, %{user_id: _receiver_id}],
      voicemail: %{url: url}
    } do
      assert_receive {Calls, [:voicemail, :sent], %Voicemail{} = voicemail}

      assert voicemail.url == url
      # TODO caller_id
    end
  end

  describe "save_contact_offer/3 for archived match side-effects" do
    setup [:with_profiles]

    setup %{profiles: [_p1, p2]} do
      Calls.subscribe_for_user(p2.user_id)
    end

    setup [:with_archived_match, :with_voicemail]

    test "archived match is unarchived", %{
      profiles: [_p1, %{user_id: receiver_id}],
      voicemail: %{url: url}
    } do
      assert_receive {Calls, [:voicemail, :sent], %Voicemail{} = voicemail}

      assert voicemail.url == url
      # TODO caller_id

      assert Matches.list_archived_matches(receiver_id) == []
    end
  end

  describe "counter-offer" do
    setup [:with_profiles, :with_match]

    # TODO voicemail from B to A overwrites earlier sent voicemail from A to B
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

    assert length(Matches.list_archived_matches(p2.user_id)) == 1

    {:ok, match: match}
  end

  defp with_voicemail(%{profiles: [p1, _p2], match: match}) do
    s3_key = "f2cb52d1-423e-4fd9-be7c-24287e0d977c"

    assert {:ok, %Voicemail{} = voicemail} =
             Calls.voicemail_save_message(
               p1.user_id,
               match.id,
               s3_key
             )

    {:ok, voicemail: %Voicemail{voicemail | url: Calls.voicemail_url(s3_key)}}
  end
end
