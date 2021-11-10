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
                         "answer" => "msu",
                         "dimensions" => [400, 800],
                         "position" => [150, 150],
                         "question" => "university",
                         "type" => "answer",
                         "value" => "🥊\nменя воспитала улица"
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

  describe "presence" do
    setup :called

    # this test is more like an example of what to expect from the channel
    test "receives presence_state and presence_diff on join/leave", %{
      me: me,
      caller: caller,
      call: call
    } do
      # presence_state push for me
      # %{"0000017a-d3ca-b85f-1e00-8a0e24450000" => %{metas: [%{phx_ref: "FpRyMAcUMICp8gRC"}]}}
      assert_push "presence_state", push
      assert Map.keys(push) == [me.id]

      # presence_diff broadcast for everyone
      # %{joins: %{"0000017a-d3cc-80ff-1e00-8a0e24450000" => %{metas: [%{phx_ref: "FpRySz8Q2LAFWQeB"}]}}, leaves: %{}}
      assert_broadcast "presence_diff", %{joins: joins, leaves: leaves}
      assert leaves == %{}
      assert Map.keys(joins) == [me.id]

      # presence_diff push for me (but why)
      # %{joins: %{"0000017a-d3cd-aee1-1e00-8a0e24450000" => %{metas: [%{phx_ref: "FpRyXTwpvQgFWQUC"}]}}, leaves: %{}}
      assert_push "presence_diff", %{joins: joins, leaves: leaves}
      assert leaves == %{}
      assert Map.keys(joins) == [me.id]

      parent = self()

      spawn(fn ->
        Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
        socket = connected_socket(caller)
        assert {:ok, _reply, socket} = subscribe_and_join(socket, "call:#{call.id}")

        # presence_state push for caller
        # %{
        #   "0000017a-d3d0-501d-1e00-8a0e24450000" => %{metas: [%{phx_ref: "FpRyhV0obTgFWQHC"}]},
        #   "0000017a-d3d0-503e-1e00-8a0e24450000" => %{metas: [%{phx_ref: "FpRyhV1gztAFWQJi"}]}
        # }
        assert_push "presence_state", push
        assert Map.keys(push) == [me.id, caller.id]

        # presence_diff broadcast for everyone
        assert_broadcast "presence_diff", %{joins: joins, leaves: leaves}
        assert leaves == %{}
        assert Map.keys(joins) == [caller.id]

        # presence_diff push for caller (but why)
        assert_push "presence_diff", %{joins: joins, leaves: leaves}
        assert leaves == %{}
        assert Map.keys(joins) == [caller.id]

        # %{
        #   "0000017a-d3e0-3cd6-1e00-8a0e24450000" => %{
        #     metas: [%{phx_ref: "FpRzeFr6EBgFWQGi"}]
        #   },
        #   "0000017a-d3e0-3cf7-1e00-8a0e24450000" => %{
        #     metas: [%{phx_ref: "FpRzeFssR5AFWQih"}]
        #   }
        # }
        assert socket |> TWeb.Presence.list() |> Map.keys() == [me.id, caller.id]

        leave(socket)
      end)

      # presence_diff broadcast for everyone
      assert_broadcast "presence_diff", %{joins: joins, leaves: leaves}
      assert leaves == %{}
      assert Map.keys(joins) == [caller.id]

      # presence_diff push for me
      assert_push "presence_diff", %{joins: joins, leaves: leaves}
      assert leaves == %{}
      assert Map.keys(joins) == [caller.id]

      # presence_diff broadcast for everyone
      assert_broadcast "presence_diff", %{joins: joins, leaves: leaves}
      assert joins == %{}
      assert Map.keys(leaves) == [caller.id]

      # presence_diff push for me
      assert_push "presence_diff", %{joins: joins, leaves: leaves}
      assert joins == %{}
      assert Map.keys(leaves) == [caller.id]
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
