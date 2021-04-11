defmodule TWeb.MobileAuthControllerTest do
  use TWeb.ConnCase, async: true
  alias T.Accounts

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
               "birthdate" => nil,
               "city" => nil,
               "first_date_idea" => nil,
               "free_form" => nil,
               "gender" => nil,
               "height" => nil,
               "interests" => nil,
               "job" => nil,
               "major" => nil,
               "most_important_in_life" => nil,
               "name" => nil,
               "occupation" => nil,
               "photos" => [],
               "tastes" => nil,
               "university" => nil
             }

      assert Accounts.get_user!(user_id)
      raw_token = Accounts.UserToken.raw_token(token)

      assert %Accounts.User{id: ^user_id} =
               user = Accounts.get_user_by_session_token(raw_token, "mobile")

      # existing user (TODO split test)
      user = Repo.preload(user, :profile)

      assert {:ok, _profile} =
               Accounts.onboard_profile(user.profile, %{
                 birthdate: "1992-12-12",
                 song: apple_music_song(),
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
                   "size" => [400, 800],
                   "background" => %{
                     "proxy" =>
                       "https://pretend-this-is-real.example.com/hlFc12KS0pCFSPajrhwUG0nHHOyH0ojGqkD3Ug4XpM4/fit/1000/1000/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL2E",
                     "s3" => "https://pretend-this-is-real.s3.amazonaws.com/a",
                     "s3_key" => "a"
                   },
                   "labels" => [
                     %{
                       "answer" => "that",
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "name",
                       "value" => "🏷\nthat"
                     },
                     %{
                       "answer" => "1992-12-12",
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "birthdate",
                       #  one day it would break
                       "value" => "🎂\n28"
                     },
                     %{
                       "answer" => 120,
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "height",
                       "value" => "📏\n120см"
                     }
                   ]
                 },
                 %{
                   "size" => [400, 800],
                   "background" => %{"color" => "#E5E7EB"},
                   "labels" => [
                     %{
                       "answer" => "Moscow",
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "city",
                       "value" => "🏙\nMoscow"
                     },
                     %{
                       "answer" => "this",
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "most_important_in_life",
                       "value" => "this"
                     },
                     %{
                       "answer" => "this",
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "interests",
                       "value" => "🎮\nthis"
                     }
                   ]
                 },
                 %{
                   "size" => [400, 800],
                   "background" => %{
                     "proxy" =>
                       "https://pretend-this-is-real.example.com/pyh8f3a1A2gLlSfzCeXnBkg6QXUe01MvQGMkZkxznXQ/fit/1000/1000/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL2I",
                     "s3" => "https://pretend-this-is-real.s3.amazonaws.com/b",
                     "s3_key" => "b"
                   },
                   "labels" => [
                     %{
                       "answer" => "that",
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "interests",
                       "value" => "🎮\nthat"
                     },
                     %{
                       "answer" => "asdf",
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "first_date_idea",
                       "value" => "asdf"
                     },
                     %{
                       "answer" => "not really",
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "alcohol",
                       "value" => "🥃\nnot really"
                     }
                   ]
                 },
                 %{
                   "size" => [400, 800],
                   "background" => %{"color" => "#E5E7EB"},
                   "labels" => [
                     %{
                       "answer" => "lol no",
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "books",
                       "value" => "📚\nlol no"
                     },
                     %{
                       "answer" => "nah",
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "currently_studying",
                       "value" => "🧠\nnah"
                     },
                     %{
                       "answer" => "rice",
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "music",
                       "value" => "🎧\nrice"
                     }
                   ]
                 },
                 %{
                   "size" => [400, 800],
                   "background" => %{
                     "proxy" =>
                       "https://pretend-this-is-real.example.com/bFHtU2r9NcoFJyBjJ_guaCOi3pi8uYb8sndTRt3yys0/fit/1000/1000/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL2M",
                     "s3" => "https://pretend-this-is-real.s3.amazonaws.com/c",
                     "s3_key" => "c"
                   },
                   "labels" => [
                     %{
                       "answer" => "nah",
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "smoking",
                       "value" => "🚬\nnah"
                     },
                     %{
                       "answer" => "bottles",
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "sports",
                       "value" => "⛷\nbottles"
                     },
                     %{
                       "answer" => "no",
                       "size" => [100, 100],
                       "center" => [100, 100],
                       "question" => "tv_shows",
                       "value" => "📺\nno"
                     }
                   ]
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
               "birthdate" => "1992-12-12",
               "city" => "Moscow",
               "first_date_idea" => "asdf",
               "free_form" => nil,
               "gender" => "M",
               "height" => 120,
               "interests" => ["this", "that"],
               "job" => nil,
               "major" => nil,
               "most_important_in_life" => "this",
               "name" => "that",
               "occupation" => nil,
               "photos" => [
                 %{
                   "proxy" =>
                     "https://pretend-this-is-real.example.com/hlFc12KS0pCFSPajrhwUG0nHHOyH0ojGqkD3Ug4XpM4/fit/1000/1000/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL2E",
                   "s3" => "https://pretend-this-is-real.s3.amazonaws.com/a"
                 },
                 %{
                   "proxy" =>
                     "https://pretend-this-is-real.example.com/pyh8f3a1A2gLlSfzCeXnBkg6QXUe01MvQGMkZkxznXQ/fit/1000/1000/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL2I",
                   "s3" => "https://pretend-this-is-real.s3.amazonaws.com/b"
                 },
                 %{
                   "proxy" =>
                     "https://pretend-this-is-real.example.com/bFHtU2r9NcoFJyBjJ_guaCOi3pi8uYb8sndTRt3yys0/fit/1000/1000/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL2M",
                   "s3" => "https://pretend-this-is-real.s3.amazonaws.com/c"
                 },
                 %{
                   "proxy" =>
                     "https://pretend-this-is-real.example.com/4TdokUQPc63mB1y9fCEt__EyVOGYJlEbqo8dmHoHfz4/fit/1000/1000/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL2Q",
                   "s3" => "https://pretend-this-is-real.s3.amazonaws.com/d"
                 }
               ],
               "tastes" => %{
                 "alcohol" => "not really",
                 "books" => ["lol no"],
                 "currently_studying" => ["nah"],
                 "music" => ["rice"],
                 "smoking" => "nah",
                 "sports" => ["bottles"],
                 "tv_shows" => ["no"]
               },
               "university" => nil
             }
    end
  end
end
