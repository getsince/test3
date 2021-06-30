defmodule TWeb.MobileAuthControllerTest do
  use TWeb.ConnCase, async: true
  alias T.Accounts
  alias T.Accounts.PasswordlessAuth

  describe "auth with phone number" do
    test "with valid code it works", %{conn: conn} do
      phone_number = "+79777777777"
      code = PasswordlessAuth.generate_code(phone_number)

      conn =
        post(conn, "/api/mobile/auth/verify-phone", %{
          code: code,
          phone_number: phone_number
        })

      # new user
      assert %{"user" => %{"id" => user_id} = user, "profile" => profile, "token" => token} =
               json_response(conn, 200)

      assert user == %{"id" => user_id, "blocked_at" => nil, "onboarded_at" => nil}

      assert profile == %{
               "user_id" => user_id,
               "story" => [
                 %{"background" => %{"color" => "#E5E7EB"}, "size" => [400, 800], "labels" => []},
                 %{"background" => %{"color" => "#E5E7EB"}, "size" => [400, 800], "labels" => []},
                 %{"background" => %{"color" => "#E5E7EB"}, "size" => [400, 800], "labels" => []},
                 %{"background" => %{"color" => "#E5E7EB"}, "size" => [400, 800], "labels" => []}
               ],
               "song" => nil,
               "gender" => nil,
               "name" => nil
             }

      assert Accounts.get_user!(user_id)
      raw_token = Accounts.UserToken.raw_token(token)

      assert %Accounts.User{id: ^user_id} =
               user = Accounts.get_user_by_session_token(raw_token, "mobile")

      # existing user (TODO split test)
      user = Repo.preload(user, :profile)

      assert {:ok, _profile} =
               Accounts.onboard_profile(user.profile, %{
                 song: apple_music_song(),
                 gender: "M",
                 name: "that",
                 latitude: 50,
                 longitude: 50
               })

      code = PasswordlessAuth.generate_code(phone_number)

      conn =
        post(conn, "/api/mobile/auth/verify-phone", %{
          code: code,
          phone_number: phone_number
        })

      assert %{
               "user" => %{"onboarded_at" => onboarded_at} = user,
               "profile" => profile,
               "token" => _token
             } = json_response(conn, 200)

      assert {:ok, _dt, 0} = DateTime.from_iso8601(onboarded_at)
      assert user == %{"id" => user_id, "blocked_at" => nil, "onboarded_at" => onboarded_at}

      assert profile == %{
               "user_id" => user_id,
               "story" => [
                 %{
                   "background" => %{"color" => "#E5E7EB"},
                   "labels" => [
                     %{
                       "answer" => "that",
                       "center" => [100, 100],
                       "question" => "name",
                       "size" => [100, 100],
                       "value" => "that"
                     }
                   ],
                   "size" => [400, 800]
                 }
               ],
               "song" => %{
                 "id" => "203709340",
                 "album_cover" =>
                   "https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/1d/b0/2d/1db02d23-6e40-ae43-29c9-ff31a854e8aa/074643865326.jpg/1000x1000bb.jpeg",
                 "artist_name" => "Bruce Springsteen",
                 "preview_url" =>
                   "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview71/v4/ab/b3/48/abb34824-1510-708e-57d7-870206be5ba2/mzaf_8515316732595919510.plus.aac.p.m4a",
                 "song_name" => "Dancing In the Dark"
               },
               "gender" => "M",
               "name" => "that"
             }
    end
  end
end
