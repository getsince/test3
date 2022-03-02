defmodule TWeb.CallChannelTest do
  use TWeb.ChannelCase, async: true
  alias T.Calls.Call

  describe "join" do
    test "when there is no call" do
      %{socket: socket} = make_user_socket()

      assert {:error, %{"reason" => "not_found"}} =
               join(socket, "call:576d9c92-8fc2-4f45-a251-321bad0e227b")
    end

    test "when call is for somebody else" do
      %{socket: socket} = make_user_socket()
      called = onboarded_user()
      caller = onboarded_user()
      %Call{id: call_id} = insert(:call, called: called, caller: caller)

      assert {:error, %{"reason" => "not_found"}} = join(socket, "call:#{call_id}")
    end

    test "when call has ended" do
      %{socket: socket, user: called} = make_user_socket()
      caller = onboarded_user()
      ended_at = ~U[2021-07-23 12:14:18Z]
      %Call{id: call_id} = insert(:call, called: called, caller: caller, ended_at: ended_at)

      assert {:error, %{"reason" => "ended"}} = join(socket, "call:#{call_id}")
    end

    test "as caller" do
      %{socket: socket, user: caller} = make_user_socket()
      called = onboarded_user()
      %Call{id: call_id} = insert(:call, called: called, caller: caller)

      assert {:ok, reply, _socket} = join(socket, "call:#{call_id}")

      call_topics = reply[:call_topics]

      assert reply == %{
               ice_servers: [
                 %{
                   "url" => "stun:global.stun.twilio.com:3478?transport=udp",
                   "urls" => "stun:global.stun.twilio.com:3478?transport=udp"
                 },
                 %{
                   "credential" => "B2AhKtD3x/T0vATYL2FimHFlPMTIJAmAmHBRrqAHEKc=",
                   "url" => "turn:global.turn.twilio.com:3478?transport=udp",
                   "urls" => "turn:global.turn.twilio.com:3478?transport=udp",
                   "username" =>
                     "65d32d2326762b02b0133dadd624f74333dea32e5588ef495986d9b5e4b932d3"
                 },
                 %{
                   "credential" => "B2AhKtD3x/T0vATYL2FimHFlPMTIJAmAmHBRrqAHEKc=",
                   "url" => "turn:global.turn.twilio.com:3478?transport=tcp",
                   "urls" => "turn:global.turn.twilio.com:3478?transport=tcp",
                   "username" =>
                     "65d32d2326762b02b0133dadd624f74333dea32e5588ef495986d9b5e4b932d3"
                 },
                 %{
                   "credential" => "B2AhKtD3x/T0vATYL2FimHFlPMTIJAmAmHBRrqAHEKc=",
                   "url" => "turn:global.turn.twilio.com:443?transport=tcp",
                   "urls" => "turn:global.turn.twilio.com:443?transport=tcp",
                   "username" =>
                     "65d32d2326762b02b0133dadd624f74333dea32e5588ef495986d9b5e4b932d3"
                 }
               ],
               call_topics: call_topics
             }
    end

    test "as called" do
      %{socket: socket, user: called} = make_user_socket()
      caller = onboarded_user()
      %Call{id: call_id} = insert(:call, called: called, caller: caller)

      assert {:ok, reply, _socket} = join(socket, "call:#{call_id}")

      call_topics = reply[:call_topics]

      assert reply == %{
               ice_servers: [
                 %{
                   "url" => "stun:global.stun.twilio.com:3478?transport=udp",
                   "urls" => "stun:global.stun.twilio.com:3478?transport=udp"
                 },
                 %{
                   "credential" => "B2AhKtD3x/T0vATYL2FimHFlPMTIJAmAmHBRrqAHEKc=",
                   "url" => "turn:global.turn.twilio.com:3478?transport=udp",
                   "urls" => "turn:global.turn.twilio.com:3478?transport=udp",
                   "username" =>
                     "65d32d2326762b02b0133dadd624f74333dea32e5588ef495986d9b5e4b932d3"
                 },
                 %{
                   "credential" => "B2AhKtD3x/T0vATYL2FimHFlPMTIJAmAmHBRrqAHEKc=",
                   "url" => "turn:global.turn.twilio.com:3478?transport=tcp",
                   "urls" => "turn:global.turn.twilio.com:3478?transport=tcp",
                   "username" =>
                     "65d32d2326762b02b0133dadd624f74333dea32e5588ef495986d9b5e4b932d3"
                 },
                 %{
                   "credential" => "B2AhKtD3x/T0vATYL2FimHFlPMTIJAmAmHBRrqAHEKc=",
                   "url" => "turn:global.turn.twilio.com:443?transport=tcp",
                   "urls" => "turn:global.turn.twilio.com:443?transport=tcp",
                   "username" =>
                     "65d32d2326762b02b0133dadd624f74333dea32e5588ef495986d9b5e4b932d3"
                 }
               ],
               call_topics: call_topics,
               caller: %{
                 name: "that",
                 user_id: caller.id,
                 gender: "M",
                 story: [
                   %{
                     "background" => %{
                       "proxy" =>
                         "https://d1234.cloudfront.net/e9a8Yq80qbgr7QH43crdCBPWdt6OACyhD5xWN8ysFok/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Bob3RvLmpwZw",
                       "s3_key" => "photo.jpg"
                     },
                     "labels" => [
                       %{
                         "dimensions" => [400, 800],
                         "position" => 'dd',
                         "rotation" => 21,
                         "type" => "text",
                         "value" => "just some text",
                         "zoom" => 1.2
                       },
                       %{
                         "answer" => "durov",
                         "position" => [150, 150],
                         "question" => "telegram",
                         "url" => "https://t.me/durov"
                       }
                     ]
                   }
                 ]
               }
             }
    end
  end

  describe "pick-up" do
    test "is broadcasted" do
      %{socket: socket, user: called} = make_user_socket()
      caller = onboarded_user()

      insert(:match,
        user_id_1: called.id,
        user_id_2: caller.id,
        inserted_at: ~N[2021-09-30 12:16:05]
      )

      %Call{id: call_id} = insert(:call, called: called, caller: caller)

      assert {:ok, _reply, socket} = subscribe_and_join(socket, "call:#{call_id}")

      ref = push(socket, "pick-up")
      assert_reply ref, :ok, reply
      assert reply == %{}

      assert_broadcast "pick-up", broadcast
      assert broadcast == %{}

      %Call{} = call = Repo.get(Call, call_id)
      assert call.accepted_at

      assert [%{event: "call_start"}] = T.Matches.MatchEvent |> Repo.all()
    end

    test "can only be done by called" do
      %{socket: socket, user: caller} = make_user_socket()
      called = onboarded_user()
      %Call{id: call_id} = insert(:call, called: called, caller: caller)

      assert {:ok, _reply, socket} = subscribe_and_join(socket, "call:#{call_id}")

      ref = push(socket, "pick-up")
      assert_reply ref, :error, reply
      assert reply == %{"reason" => "not_called"}

      refute_broadcast "pick-up", _

      %Call{} = call = Repo.get(Call, call_id)
      refute call.accepted_at
    end
  end

  describe "peer-message" do
    setup :called

    test "broadcast body and adds 'from' field", %{socket: socket, me: me} do
      ref = push(socket, "peer-message", %{"body" => ~s[{"sdp":"a;b;a;b;"}]})
      assert_reply ref, :ok, reply
      assert reply == %{}

      assert_broadcast "peer-message", broadcast
      assert broadcast == %{"body" => "{\"sdp\":\"a;b;a;b;\"}", "from" => me.id}
    end
  end

  describe "hang-up" do
    setup :called

    test "is broadcasted and ends the call", %{socket: socket, call: call} do
      ref = push(socket, "hang-up")
      assert_reply ref, :ok, reply
      assert reply == %{}

      assert_broadcast "hang-up", broadcast
      assert broadcast == %{}

      assert {:error, %{"reason" => "ended"}} = join(socket, "call:#{call.id}")

      %Call{} = call = Repo.get(Call, call.id)
      assert call.ended_at
    end
  end

  describe "user is busy" do
    @tag skip: true
    test "works" do
      %{socket: socket, user: called} = make_user_socket()
      caller = onboarded_user()

      # called user joined call, should not be available anymore
      %Call{id: call_id} = insert(:call, called: called, caller: caller)
      assert {:ok, _reply, _socket} = subscribe_and_join(socket, "call:#{call_id}")

      assert TWeb.CallTracker.in_call?(called.id)
      refute TWeb.CallTracker.in_call?(caller.id)

      # another user tries to call `called` user
      another_caller = onboarded_user()

      # TODO match users
      assert {:error, "receiver is busy"} = T.Calls.call(another_caller.id, called.id)
    end
  end

  defp make_user_socket do
    user = onboarded_user()
    socket = connected_socket(user)
    %{user: user, socket: socket}
  end

  defp called(_context) do
    %{socket: socket, user: called} = make_user_socket()
    caller = onboarded_user()
    %Call{id: call_id} = call = insert(:call, called: called, caller: caller)
    assert {:ok, _reply, socket} = subscribe_and_join(socket, "call:#{call_id}")
    {:ok, socket: socket, called: called, me: called, caller: caller, call: call}
  end
end
