defmodule T.CallsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: Repo
  alias T.{Matches, Calls}

  # these are already tested through feed_channel_test
  # TODO still test directly later

  describe "call/2" do
    @tag skip: true
    test "when not allowed"
    @tag skip: true
    test "call matched"
    @tag skip: true
    test "when caller is invited by called"
    @tag skip: true
    test "when missed call"
    @tag skip: true
    test "when no pushkit devices"
    @tag skip: true
    test "when push fails"
    @tag skip: true
    test "when push succeeds"
  end

  describe "get_call_role_and_peer/2" do
    @tag skip: true
    test "when caller"
    @tag skip: true
    test "when called"
    @tag skip: true
    test "when not allowed"
  end

  describe "end_call/1" do
    @tag skip: true
    test "sets ended_at on call"
  end

  describe "list_missed_calls_with_profile/1" do
    @tag skip: true
    test "lists calls without accepted_at"
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
end
