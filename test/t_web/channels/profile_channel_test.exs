defmodule TWeb.ProfileChannelTest do
  use TWeb.ChannelCase
  import Mox
  alias T.Accounts
  alias Accounts.User

  setup do
    {:ok, %User{} = user} = Accounts.register_user(%{phone_number: phone_number()})
    {:ok, user: Repo.preload(user, :profile), socket: connected_socket(user)}
  end

  describe "join" do
    test "with empty profile", %{socket: socket, user: user} do
      {:ok, reply, _socket} = subscribe_and_join(socket, "profile:" <> user.id, %{})

      assert reply == %{
               profile: %{
                 user_id: user.id,
                 song: nil,
                 birthdate: nil,
                 first_date_idea: nil,
                 free_form: nil,
                 gender: nil,
                 height: nil,
                 interests: [],
                 job: nil,
                 major: nil,
                 most_important_in_life: nil,
                 name: nil,
                 occupation: nil,
                 photos: [],
                 university: nil,
                 city: nil,
                 tastes: %{}
               }
             }
    end

    @tag skip: true
    test "with invalid user id", %{socket: socket} do
      assert {:error, %{reason: "join crashed"}} =
               subscribe_and_join(socket, "profile:" <> Ecto.UUID.generate(), %{})
    end

    test "with partially filled profile", %{socket: socket, user: user} do
      {:ok, _profile} =
        Accounts.update_profile(user.profile, %{"name" => "Jojaresum", "photos" => ["photo.jpg"]})

      assert {:ok,
              %{
                profile: %{
                  name: "Jojaresum",
                  photos: [
                    %{
                      "proxy" =>
                        "https://pretend-this-is-real.example.com/ZUj5Q59uKDQBvOlFPlOAbTkVwyfuRl_xrqiZVOCC0mM/fit/1000/1000/sm/0/" <>
                          s3_encoded_url,
                      "s3" => s3_url = "https://pretend-this-is-real.s3.amazonaws.com/photo.jpg"
                    }
                  ]
                }
              }, _socket} = subscribe_and_join(socket, "profile:" <> user.id, %{})

      assert Base.url_decode64!(s3_encoded_url, padding: false) == s3_url
    end
  end

  defp subscribe_and_join(%{socket: socket, user: user}) do
    {:ok, _reply, socket} = subscribe_and_join(socket, "profile:" <> user.id, %{})
    {:ok, socket: socket}
  end

  describe "onboarding flow" do
    setup :subscribe_and_join

    setup :verify_on_exit!

    test "submit everything at once", %{socket: socket, user: user} do
      assert user.profile.hidden? == true
      refute user.onboarded_at

      ref = push(socket, "submit", %{"profile" => %{}})
      assert_reply ref, :error, reply, 1000

      assert reply == %{
               profile: %{
                 birthdate: ["can't be blank"],
                 city: ["can't be blank"],
                 first_date_idea: ["can't be blank"],
                 gender: ["can't be blank"],
                 height: ["can't be blank"],
                 interests: ["should have at least 2 item(s)"],
                 most_important_in_life: ["can't be blank"],
                 name: ["can't be blank"],
                 photos: ["should have 4 item(s)"],
                 tastes: ["should have at least 7 tastes"],
                 song: ["can't be blank"]
               }
             }

      MockMusic
      |> expect(:get_song, fn "203709340" ->
        apple_music_song()
      end)

      ref =
        push(socket, "submit", %{
          "profile" => %{
            "name" => "hey that's me CLARISA",
            "song" => "203709340",
            # TODO birthday
            "birthdate" => "1995-01-01",
            "city" => "Moscow",
            "first_date_idea" => "dunno lol",
            "gender" => "F",
            "height" => 200,
            "interests" => ["cooking", "nothing"],
            "most_important_in_life" => "благочестие",
            # TODO validate they are on s3
            "photos" => ["a", "b", "c", "d"],
            "tastes" => %{
              "music" => ["eminem"],
              "cuisines" => ["italian"],
              "social_networks" => ["asdf"],
              "movies" => ["asdfasdf"],
              "tv_shows" => ["asdfadfs"],
              "books" => ["asdfasdf"],
              "smoking" => "asdfasdf"
            }
          }
        })

      assert_reply ref, :ok, reply, 1000

      assert reply == %{
               profile: %{
                 user_id: user.id,
                 song: %{
                   "id" => "203709340",
                   "album_cover" =>
                     "https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/1d/b0/2d/1db02d23-6e40-ae43-29c9-ff31a854e8aa/074643865326.jpg/1000x1000bb.jpeg",
                   "artist_name" => "Bruce Springsteen",
                   "preview_url" =>
                     "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview71/v4/ab/b3/48/abb34824-1510-708e-57d7-870206be5ba2/mzaf_8515316732595919510.plus.aac.p.m4a",
                   "song_name" => "Dancing In the Dark"
                 },
                 birthdate: ~D[1995-01-01],
                 city: "Moscow",
                 first_date_idea: "dunno lol",
                 free_form: nil,
                 gender: "F",
                 height: 200,
                 interests: ["cooking", "nothing"],
                 job: nil,
                 major: nil,
                 most_important_in_life: "благочестие",
                 name: "hey that's me CLARISA",
                 occupation: nil,
                 photos: reply.profile.photos,
                 tastes: %{
                   "books" => ["asdfasdf"],
                   "cuisines" => ["italian"],
                   "movies" => ["asdfasdf"],
                   "music" => ["eminem"],
                   "smoking" => "asdfasdf",
                   "social_networks" => ["asdf"],
                   "tv_shows" => ["asdfadfs"]
                 },
                 university: nil
               }
             }

      assert length(reply.profile.photos) == 4

      user = User |> Repo.get(user.id) |> Repo.preload([:profile])
      assert user.profile.hidden? == false
      assert user.onboarded_at
    end
  end

  describe "upload-preflight" do
    setup :subscribe_and_join

    test "it works", %{socket: socket} do
      ref = push(socket, "upload-preflight", %{"media" => %{"content-type" => "image/jpeg"}})
      assert_reply ref, :ok, reply, 1000

      # TODO use forms
      # assert %{
      #          fields: %{
      #            "acl" => "private",
      #            "content-type" => "image/jpeg",
      #            "key" => key,
      #            "policy" => _policy,
      #            "x-amz-algorithm" => "AWS4-HMAC-SHA256",
      #            "x-amz-credential" => _credential,
      #            "x-amz-date" => _date,
      #            "x-amz-server-side-encryption" => "AES256",
      #            "x-amz-signature" => _signature
      #          },
      #          key: key,
      #          url: "https://pretend-this-is-real.s3.amazonaws.com"
      #        } = reply

      assert %{
               key: key,
               url: "https://pretend-this-is-real.s3.amazonaws.com",
               fields: %{
                 "acl" => "public-read",
                 "content-type" => "image/jpeg",
                 "key" => key,
                 "policy" => _policy,
                 "x-amz-algorithm" => "AWS4-HMAC-SHA256",
                 "x-amz-credential" => _creds,
                 "x-amz-date" => _date,
                 "x-amz-server-side-encryption" => "AES256",
                 "x-amz-signature" => _signature
               }
             } = reply
    end
  end

  describe "photos" do
    setup :subscribe_and_join

    @tag skip: true
    test "validation passes after three photos", %{socket: socket} do
      ref = push(socket, "submit", %{"photos" => ["photo.jpg"]})
      assert_reply ref, :ok, %{profile: %{photos: ["photo.jpg"]}}

      ref = push(socket, "validate", %{"step" => "photos"})
      assert_reply ref, :error, %{photos: ["should have at least 3 item(s)"]}

      ref = push(socket, "submit", %{"photos" => ["photo.jpg", "photo2.jpg", "photo3.jpg"]})
      assert_reply ref, :ok, %{profile: %{photos: ["photo.jpg", "photo2.jpg", "photo3.jpg"]}}

      ref = push(socket, "validate", %{"step" => "photos"})
      assert_reply ref, :ok, %{profile: %{photos: ["photo.jpg", "photo2.jpg", "photo3.jpg"]}}
    end
  end

  describe "general info" do
    setup :subscribe_and_join

    @tag skip: true
    test "validation passes after all fields are set", %{socket: socket} do
      ref = push(socket, "submit", %{"name" => "Jerasimus The Detached"})
      assert_reply ref, :ok, %{profile: %{name: "Jerasimus The Detached"}}

      ref = push(socket, "validate", %{"step" => "general-info"})

      assert_reply ref, :error, %{
        birthdate: ["can't be blank"],
        gender: ["can't be blank"],
        height: ["can't be blank"],
        home_city: ["can't be blank"]
      }

      ref = push(socket, "submit", %{"birthdate" => "2000-01-01"})
      assert_reply ref, :ok, %{profile: %{birthdate: ~D[2000-01-01]}}

      ref = push(socket, "submit", %{"gender" => "M"})
      assert_reply ref, :ok, %{profile: %{gender: "M"}}

      ref = push(socket, "submit", %{"height" => 130})
      assert_reply ref, :ok, %{profile: %{height: 130}}

      ref = push(socket, "submit", %{"home_city" => "Moscow"})
      assert_reply ref, :ok, %{profile: %{home_city: "Moscow"}}

      ref = push(socket, "validate", %{"step" => "general-info"})

      assert_reply ref, :ok, %{
        profile: %{
          name: "Jerasimus The Detached",
          birthdate: ~D[2000-01-01],
          gender: "M",
          height: 130,
          home_city: "Moscow"
        }
      }
    end
  end

  describe "work-and-education" do
    setup :subscribe_and_join

    @tag skip: true
    test "validation passes without any data, but data can be submitted", %{socket: socket} do
      ref = push(socket, "validate", %{"step" => "work-and-education"})
      assert_reply ref, :ok, %{profile: %{}}

      ref = push(socket, "submit", %{"occupation" => "none"})
      assert_reply ref, :ok, %{profile: %{occupation: "none"}}

      ref = push(socket, "submit", %{"job" => "none"})
      assert_reply ref, :ok, %{profile: %{job: "none"}}

      ref = push(socket, "submit", %{"university" => "nil"})
      assert_reply ref, :ok, %{profile: %{university: "nil"}}

      ref = push(socket, "submit", %{"major" => "net"})
      assert_reply ref, :ok, %{profile: %{major: "net"}}

      ref = push(socket, "validate", %{"step" => "work-and-education"})
      assert_reply ref, :ok, %{profile: %{}}
    end
  end

  describe "about" do
    setup :subscribe_and_join

    @tag skip: true
    test "validaton passes after required fields are set", %{socket: socket} do
      ref = push(socket, "validate", %{"step" => "about"})

      assert_reply ref, :error, %{
        first_date_idea: ["can't be blank"],
        interests: ["should have at least 2 item(s)"],
        most_important_in_life: ["can't be blank"]
      }

      ref = push(socket, "submit", %{"most_important_in_life" => "knowledge"})
      assert_reply ref, :ok, %{profile: %{most_important_in_life: "knowledge"}}

      ref = push(socket, "submit", %{"first_date_idea" => "going to a library together"})
      assert_reply ref, :ok, %{profile: %{first_date_idea: "going to a library together"}}

      # TODO should return an error
      ref = push(socket, "submit", %{"interests" => []})
      assert_reply ref, :ok, %{profile: %{interests: []}}

      ref = push(socket, "submit", %{"interests" => ["reading"]})
      assert_reply ref, :error, %{interests: ["should have at least 2 item(s)"]}

      ref = push(socket, "validate", %{"step" => "about"})
      assert_reply ref, :error, %{interests: ["should have at least 2 item(s)"]}

      ref = push(socket, "submit", %{"interests" => ["reading", "thinking"]})
      assert_reply ref, :ok, %{profile: %{interests: ["reading", "thinking"]}}

      ref = push(socket, "validate", %{"step" => "about"})
      assert_reply ref, :ok, %{profile: %{}}
    end
  end

  describe "tastes" do
    setup :subscribe_and_join

    @tag skip: true
    test "validation passes after 7 fields are filled", %{socket: socket} do
      ref = push(socket, "validate", %{"step" => "tastes"})
      assert_reply ref, :error, %{tastes: ["should have at least 7 tastes"]}

      ref = push(socket, "submit", %{"music" => ["a", "b", "c"]})
      assert_reply ref, :ok, %{profile: %{music: ["a", "b", "c"]}}

      ref = push(socket, "submit", %{"smoking" => "always"})
      assert_reply ref, :ok, %{profile: %{smoking: "always"}}

      ref = push(socket, "submit", %{"alcohol" => "never before breaskfast"})
      assert_reply ref, :ok, %{profile: %{alcohol: "never before breaskfast"}}

      ref = push(socket, "validate", %{"step" => "tastes"})
      assert_reply ref, :error, %{tastes: ["should have at least 7 tastes"]}

      ref = push(socket, "submit", %{"sports" => ["a", "b", "c"]})
      assert_reply ref, :ok, %{profile: %{sports: ["a", "b", "c"]}}

      ref = push(socket, "submit", %{"books" => ["a", "b", "c"]})
      assert_reply ref, :ok, %{profile: %{books: ["a", "b", "c"]}}

      ref = push(socket, "submit", %{"tv_shows" => ["a", "b", "c"]})
      assert_reply ref, :ok, %{profile: %{tv_shows: ["a", "b", "c"]}}

      # TODO check all fields
      ref = push(socket, "submit", %{"languages" => ["a", "b", "c"]})
      assert_reply ref, :ok, %{profile: %{languages: ["a", "b", "c"]}}

      ref = push(socket, "validate", %{"step" => "tastes"})
      assert_reply ref, :ok, %{profile: %{}}
    end
  end

  describe "final check" do
    setup :subscribe_and_join

    @tag skip: true
    test "with complete profile" do
      # TODO
    end
  end
end
