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
                 latitude: nil,
                 longitude: nil,
                 gender_preference: nil,
                 story: [
                   %{
                     "background" => %{"color" => "#E5E7EB"},
                     "size" => [400, 800],
                     "labels" => []
                   },
                   %{
                     "background" => %{"color" => "#E5E7EB"},
                     "size" => [400, 800],
                     "labels" => []
                   },
                   %{
                     "background" => %{"color" => "#E5E7EB"},
                     "size" => [400, 800],
                     "labels" => []
                   },
                   %{
                     "background" => %{"color" => "#E5E7EB"},
                     "size" => [400, 800],
                     "labels" => []
                   }
                 ],
                 song: nil,
                 gender: nil,
                 name: nil
               }
             }
    end

    @tag skip: true
    test "with invalid user id", %{socket: socket} do
      assert {:error, %{reason: "join crashed"}} =
               subscribe_and_join(socket, "profile:" <> Ecto.UUID.generate(), %{})
    end

    test "with partially filled profile", %{socket: socket, user: user} do
      # TODO remove photos
      {:ok, _profile} =
        Accounts.update_profile(user.profile, %{
          "name" => "Jojaresum",
          "story" => [
            %{
              "background" => %{"s3_key" => "photo.jpg"},
              "labels" => [
                %{
                  "type" => "text",
                  "value" => "just some text",
                  "position" => [100, 100],
                  "rotation" => 21,
                  "zoom" => 1.2,
                  "dimensions" => [400, 800]
                },
                %{
                  "type" => "answer",
                  "question" => "university",
                  "answer" => "msu",
                  "value" => "🥊\nменя воспитала улица",
                  "position" => [150, 150],
                  "dimensions" => [400, 800]
                }
              ]
            }
          ]
        })

      assert {:ok,
              %{
                profile: %{
                  name: "Jojaresum",
                  story: [
                    %{
                      "background" => %{
                        "proxy" =>
                          "https://d1234.cloudfront.net/e9a8Yq80qbgr7QH43crdCBPWdt6OACyhD5xWN8ysFok/fit/1000/0/sm/0/aHR0cHM6Ly9wcmV0ZW5kLXRoaXMtaXMtcmVhbC5zMy5hbWF6b25hd3MuY29tL3Bob3RvLmpwZw",
                        "s3_key" => "photo.jpg"
                      },
                      "labels" => [
                        %{
                          "type" => "text",
                          "value" => "just some text",
                          "dimensions" => [400, 800],
                          "position" => [100, 100],
                          "rotation" => 21,
                          "zoom" => 1.2
                        },
                        %{
                          "type" => "answer",
                          "answer" => "msu",
                          "question" => "university",
                          "value" => "🥊\nменя воспитала улица",
                          "dimensions" => [400, 800],
                          "position" => [150, 150]
                        }
                      ]
                    }
                  ]
                }
              }, _socket} = subscribe_and_join(socket, "profile:" <> user.id, %{})
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
                 gender: ["can't be blank"],
                 name: ["can't be blank"],
                 location: ["can't be blank"]
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
            "gender" => "F",
            "latitude" => 50,
            "longitude" => 50,
            # TODO validate photos are on s3
            "story" => profile_story(),
            "gender_preference" => ["F", "M"]
          }
        })

      assert_reply ref, :ok, reply, 1000

      assert reply == %{
               profile: %{
                 user_id: user.id,
                 latitude: 50,
                 longitude: 50,
                 gender_preference: ["F", "M"],
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
                 song: %{
                   "id" => "203709340",
                   "album_cover" =>
                     "https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/1d/b0/2d/1db02d23-6e40-ae43-29c9-ff31a854e8aa/074643865326.jpg/1000x1000bb.jpeg",
                   "artist_name" => "Bruce Springsteen",
                   "preview_url" =>
                     "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview71/v4/ab/b3/48/abb34824-1510-708e-57d7-870206be5ba2/mzaf_8515316732595919510.plus.aac.p.m4a",
                   "song_name" => "Dancing In the Dark"
                 },
                 gender: "F",
                 name: "hey that's me CLARISA"
               }
             }

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

  describe "updates after onboarded" do
    setup %{user: user} do
      {:ok, user: onboarded_user(user)}
    end

    setup :subscribe_and_join

    test "can reset song", %{user: user, socket: socket} do
      assert user.profile.song

      ref = push(socket, "submit", %{"profile" => %{"song" => ""}})
      assert_reply ref, :ok, %{profile: %{song: nil}}

      refute Repo.get!(Accounts.Profile, user.id).song
    end
  end
end
