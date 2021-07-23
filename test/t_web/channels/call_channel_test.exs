defmodule TWeb.CallChannelTest do
  use TWeb.ChannelCase

  describe "join" do
    test "when there is no call"
    test "when call is for somebody else"
    test "when call has ended"
    test "as caller"
    test "as called"
  end

  describe "hang-up" do
    test "end the call"
  end

  describe "peer-message" do
    test "relays body intact and adds 'from' field"
  end

  describe "presence" do
    test "it works"
  end
end
