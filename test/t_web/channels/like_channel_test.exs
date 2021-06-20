defmodule TWeb.LikeChannelTest do
  use TWeb.ChannelCase

  setup do
    me = onboarded_user()
    {:ok, me: me, socket: connected_socket(me)}
  end

  describe "join version 1" do
    test "with no likers", %{me: me, socket: socket} do
      assert {:ok, reply, _socket} = subscribe_and_join(socket, "likes:" <> me.id, %{})
      assert reply == %{likers: [], version: 1}
    end

    test "with likers", %{me: me, socket: socket} do
      [matched | likers] = insert_list(3, :profile)
      insert(:match, alive?: true, user_id_1: me.id, user_id_2: matched.user_id)
      Enum.each(likers, fn l -> insert(:like, by_user: l.user, user: me) end)

      assert {:ok, %{likers: likers}, _socket} =
               subscribe_and_join(socket, "likes:" <> me.id, %{})

      # likers rendered as profiles
      assert [
               %{
                 gender: "M",
                 name: nil,
                 seen?: false,
                 song: nil,
                 story: [_ | _],
                 user_id: _
               },
               %{
                 gender: "M",
                 name: nil,
                 seen?: false,
                 song: nil,
                 story: [_ | _],
                 user_id: _
               }
             ] = likers
    end
  end

  describe "join version 2" do
    test "with no likers", %{me: me, socket: socket} do
      assert {:ok, reply, _socket} =
               subscribe_and_join(socket, "likes:" <> me.id, %{"version" => 2})

      assert reply == %{likes: [], version: 2}
    end

    test "with likers", %{me: me, socket: socket} do
      [matched | likers] = insert_list(3, :profile)
      insert(:match, alive?: true, user_id_1: me.id, user_id_2: matched.user_id)
      Enum.each(likers, fn l -> insert(:like, by_user: l.user, user: me) end)

      assert {:ok, %{likes: likes}, _socket} =
               subscribe_and_join(socket, "likes:" <> me.id, %{"version" => 2})

      # rendered as likes
      assert [
               %{
                 inserted_at: %DateTime{},
                 profile: %{
                   gender: "M",
                   name: nil,
                   song: nil,
                   story: [_ | _],
                   user_id: _
                 },
                 seen?: false
               },
               %{
                 inserted_at: %DateTime{},
                 profile: %{
                   gender: "M",
                   name: nil,
                   song: nil,
                   story: [_ | _],
                   user_id: _
                 },
                 seen?: false
               }
             ] = likes
    end
  end

  describe "like notification" do
    test "notified when liked", %{me: me, socket: socket} do
      assert {:ok, _reply, _socket} = subscribe_and_join(socket, "likes:" <> me.id, %{})
      %{id: liker_id} = liker = onboarded_user()

      spawn(fn ->
        socket = connected_socket(liker)
        {:ok, _reply, socket} = subscribe_and_join(socket, "feed:" <> liker.id, %{})
        ref = push(socket, "like", %{"profile_id" => me.id})
        assert_reply ref, :ok, %{}
      end)

      assert_push "liked", %{like: like}

      assert %{
               inserted_at: %DateTime{},
               profile: %{
                 gender: "M",
                 name: "that",
                 song: %{
                   "album_cover" =>
                     "https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/1d/b0/2d/1db02d23-6e40-ae43-29c9-ff31a854e8aa/074643865326.jpg/1000x1000bb.jpeg",
                   "artist_name" => "Bruce Springsteen",
                   "id" => "203709340",
                   "preview_url" =>
                     "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview71/v4/ab/b3/48/abb34824-1510-708e-57d7-870206be5ba2/mzaf_8515316732595919510.plus.aac.p.m4a",
                   "song_name" => "Dancing In the Dark"
                 },
                 story: [
                   %{
                     "background" => %{
                       "proxy" =>
                         "https://d1234.cloudfront.net/ZUj5Q59uKDQBvOlFPlOAbTkVwyfuRl_xrqiZVOCC0mM/fit/1000/1000/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Bob3RvLmpwZw",
                       "s3_key" => "photo.jpg"
                     },
                     "labels" => [
                       %{
                         "dimensions" => [400, 800],
                         "position" => [100, 100],
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
                 ],
                 user_id: ^liker_id
               },
               seen?: false
             } = like
    end
  end
end
