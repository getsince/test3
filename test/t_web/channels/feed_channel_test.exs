defmodule TWeb.FeedChannelTest do
  use TWeb.ChannelCase, async: true
  alias T.{Accounts, Matches}
  alias T.Accounts.User

  setup do
    {:ok, %User{} = user} = Accounts.register_user(%{phone_number: phone_number()})

    {:ok, _profile} =
      Accounts.onboard_profile(user.profile, %{
        birthdate: "1992-12-12",
        city: "Moscow",
        first_date_idea: "asdf",
        gender: "M",
        height: 120,
        interests: ["this", "that"],
        most_important_in_life: "this",
        name: "that",
        photos: ["a", "b", "c", "d"],
        tastes: %{
          music: ["rice"],
          sports: ["bottles"],
          alcohol: "not really",
          smoking: "nah",
          books: ["lol no"],
          tv_shows: ["no"],
          currently_studying: ["nah"]
        }
      })

    {:ok, user: Repo.preload(user, :profile), socket: connected_socket(user)}
  end

  describe "join" do
    test "with current match, get match", %{socket: socket, user: user} do
      p2 = insert(:profile, hidden?: true, gender: "F")
      match = insert(:match, user_id_1: user.id, user_id_2: p2.user_id, alive?: true)

      assert {:ok, reply, _socket} =
               subscribe_and_join(socket, "feed:" <> user.id, %{"timezone" => "Europe/Moscow"})

      assert reply == %{
               match: %{
                 id: match.id,
                 profile: %{
                   birthdate: nil,
                   city: nil,
                   first_date_idea: nil,
                   free_form: nil,
                   gender: "F",
                   height: nil,
                   interests: [],
                   job: nil,
                   major: nil,
                   most_important_in_life: nil,
                   name: nil,
                   occupation: nil,
                   photos: [],
                   tastes: %{},
                   university: nil,
                   user_id: p2.user_id
                 }
               }
             }
    end

    test "without match, get feed", %{socket: socket, user: user} do
      me = user.profile

      profiles = insert_list(20, :profile, gender: "F")

      [_place1 | [_place2 | _rest]] = most_liked(profiles, 30..15)
      [_place3 | [place4 | _rest]] = personality_overlap(profiles, me, 30..10)
      insert(:like, by_user_id: place4.user_id, user_id: me.user_id)

      assert {:ok, reply, _socket} =
               subscribe_and_join(socket, "feed:" <> user.id, %{"timezone" => "Europe/Moscow"})

      assert length(reply.feed) == 5
    end
  end

  # TODO do auth check
  describe "like profile" do
    setup [:with_other_profile, :subscribe_and_join]

    test "no prev like -> no match", %{socket: socket, profile: p} do
      ref = push(socket, "like", %{"profile_id" => p.user_id})

      assert_reply ref, :ok, reply, 1000
      assert reply == %{}
      refute_push _event, _payload
    end

    test "has prev like -> match", %{socket: socket, user: user, profile: p} do
      insert(:like, by_user_id: p.user_id, user_id: user.id)

      ref = push(socket, "like", %{"profile_id" => p.user_id})

      assert_reply ref, :ok, reply, 1000
      assert reply == %{}
      assert_push "matched", payload
      assert %{id: match_id} = Matches.get_current_match(user.id)

      assert payload == %{
               match: %{
                 id: match_id,
                 profile: %{
                   birthdate: nil,
                   city: nil,
                   first_date_idea: nil,
                   free_form: nil,
                   gender: "F",
                   height: nil,
                   interests: [],
                   job: nil,
                   major: nil,
                   most_important_in_life: nil,
                   name: nil,
                   occupation: nil,
                   photos: [],
                   tastes: %{},
                   university: nil,
                   user_id: p.user_id
                 }
               }
             }
    end
  end

  # TODO do auth check
  describe "dislike profile" do
    setup [:with_other_profile, :subscribe_and_join]

    test "nothing happens", %{socket: socket, profile: p} do
      ref = push(socket, "dislike", %{"profile_id" => p.user_id})

      assert_reply ref, :ok, reply, 1000
      assert reply == %{}
      refute_push _event, _payload
    end
  end

  defp with_other_profile(_context) do
    {:ok, profile: insert(:profile, gender: "F")}
  end

  defp subscribe_and_join(%{user: user, socket: socket}) do
    assert {:ok, _reply, socket} =
             subscribe_and_join(socket, "feed:" <> user.id, %{"timezone" => "Europe/Moscow"})

    {:ok, socket: socket}
  end
end
