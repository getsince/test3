defmodule T.CallsTest do
  use T.DataCase, async: true

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
end
