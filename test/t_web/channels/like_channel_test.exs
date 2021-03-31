defmodule TWeb.LikeChannelTest do
  use TWeb.ChannelCase

  setup do
    me = onboarded_user()
    {:ok, me: me, socket: connected_socket(me)}
  end

  describe "join" do
    test "with no likers", %{me: me, socket: socket} do
      assert {:ok, reply, _socket} = subscribe_and_join(socket, "likes:" <> me.id, %{})
      assert reply == %{likers: []}
    end

    test "with likers", %{me: me, socket: socket} do
      likers = insert_list(3, :profile)
      Enum.each(likers, fn l -> insert(:like, by_user: l.user, user: me) end)

      assert {:ok, %{likers: [_, _, _]}, _socket} =
               subscribe_and_join(socket, "likes:" <> me.id, %{})
    end
  end

  describe "like notification" do
    test "notified when liked", %{me: me, socket: socket} do
      assert {:ok, _reply, _socket} = subscribe_and_join(socket, "likes:" <> me.id, %{})
      liker = onboarded_user()

      spawn(fn ->
        socket = connected_socket(liker)
        {:ok, _reply, socket} = subscribe_and_join(socket, "feed:" <> liker.id, %{})
        ref = push(socket, "like", %{"profile_id" => me.id})
        assert_reply ref, nil
      end)

      assert_push "liked", %{liker: recv_liker}
      assert recv_liker.user_id == liker.id
    end
  end
end
