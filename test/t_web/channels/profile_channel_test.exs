defmodule TWeb.ProfileChannelTest do
  use TWeb.ChannelCase, async: true
  import Mox
  alias T.Accounts
  alias Accounts.User

  describe "join with empty profile" do
    setup do
      user = registered_user()
      {:ok, user: user, socket: connected_socket(user)}
    end

    test "with empty profile", %{socket: socket, user: user} do
      {:ok, %{profile: profile, stickers: %{}}, _socket} =
        subscribe_and_join(socket, "profile:" <> user.id, %{})

      assert profile == %{
               user_id: user.id,
               latitude: nil,
               longitude: nil,
               gender_preference: [],
               distance: nil,
               max_age: nil,
               min_age: nil,
               story: [],
               gender: nil,
               name: nil,
               birthdate: nil,
               address: nil,
               premium: false
             }
    end
  end

  describe "join with onboarded profile" do
    setup do
      story = [
        %{
          "background" => %{
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
          ],
          "size" => [400, 100]
        },
        %{
          "background" => %{"s3_key" => "private.jpg"},
          "blurred" => %{"s3_key" => "blurred.jpg"},
          "labels" => [
            %{
              "type" => "text",
              "value" => "I vote for Putin, unmatch if you don't",
              "position" => [100, 100]
            }
          ],
          "size" => [100, 400]
        }
      ]

      user = onboarded_user(story: story)
      {:ok, user: user, socket: connected_socket(user)}
    end

    test "with invalid user id", %{socket: socket} do
      assert {:error, %{"error" => "forbidden"}} =
               join(socket, "profile:" <> Ecto.UUID.generate())
    end

    test "private pages contain all fields", %{socket: socket, user: user} do
      assert {:ok, %{profile: profile}, _socket} = join(socket, "profile:" <> user.id)
      assert [public, private] = profile.story

      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["background", "blurred", "labels", "private", "size"]

      assert %{
               "private" => true,
               "blurred" => %{
                 "proxy" => "https://d1234.cloudfront.net/" <> _,
                 "s3_key" => "blurred.jpg"
               },
               "background" => %{
                 "proxy" => "https://d1234.cloudfront.net/" <> _,
                 "s3_key" => "private.jpg"
               },
               "labels" => [
                 %{
                   "position" => [100, 100],
                   "type" => "text",
                   "value" => "I vote for Putin, unmatch if you don't"
                 }
               ]
             } = private
    end

    test "with partially filled profile", %{socket: socket, user: user} do
      {:ok, _profile} =
        Accounts.update_profile(user.id, %{
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

      assert {:ok, %{profile: profile}, _socket} =
               subscribe_and_join(socket, "profile:" <> user.id, %{})

      assert profile == %{
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
               ],
               gender: "M",
               gender_preference: ["F", "M", "N"],
               distance: nil,
               max_age: nil,
               min_age: nil,
               latitude: 55.755833,
               longitude: 37.617222,
               birthdate: ~D[1998-10-28],
               user_id: user.id,
               address: %{
                 "en_US" => %{
                   "city" => "Buenos Aires",
                   "state" => "Autonomous City of Buenos Aires",
                   "country" => "Argentina",
                   "iso_country_code" => "AR"
                 }
               },
               premium: false
             }
    end
  end

  defp subscribe_and_join(%{socket: socket, user: user}) do
    {:ok, _reply, socket} = subscribe_and_join(socket, "profile:" <> user.id, %{})
    {:ok, socket: socket}
  end

  describe "onboarding flow" do
    setup do
      user = registered_user()
      {:ok, user: user, socket: connected_socket(user)}
    end

    setup :subscribe_and_join

    setup :verify_on_exit!

    test "submit everything at once", %{socket: socket, user: user} do
      assert user.profile.hidden? == true
      refute user.onboarded_at

      ref = push(socket, "submit", %{"profile" => %{}})
      assert_reply(ref, :error, reply, 1000)

      assert reply == %{
               profile: %{
                 gender: ["can't be blank"],
                 name: ["can't be blank"],
                 location: ["can't be blank"],
                 birthdate: ["can't be blank"]
               }
             }

      ref =
        push(socket, "submit", %{
          "profile" => %{
            "name" => "hey that's me CLARISA",
            "gender" => "F",
            "birthdate" => "1995-10-28",
            "latitude" => 50,
            "longitude" => 50,
            # TODO validate photos are on s3
            "story" => profile_story(),
            "gender_preference" => ["F", "M"],
            "distance" => 10,
            "min_age" => 18,
            "max_age" => 40,
            "address" => %{
              "en_US" => %{
                "city" => "Buenos Aires",
                "state" => "Autonomous City of Buenos Aires",
                "country" => "Argentina",
                "iso_country_code" => "AR"
              }
            }
          }
        })

      assert_reply(ref, :ok, reply, 1000)

      assert reply == %{
               profile: %{
                 user_id: user.id,
                 latitude: 50,
                 longitude: 50,
                 gender_preference: ["F", "M"],
                 distance: 10,
                 min_age: 18,
                 max_age: 40,
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
                         "answer" => "durov",
                         "position" => [150, 150],
                         "question" => "telegram",
                         "url" => "https://t.me/durov"
                       }
                     ]
                   }
                 ],
                 gender: "F",
                 name: "hey that's me CLARISA",
                 birthdate: ~D[1995-10-28],
                 address: %{
                   "en_US" => %{
                     "city" => "Buenos Aires",
                     "state" => "Autonomous City of Buenos Aires",
                     "country" => "Argentina",
                     "iso_country_code" => "AR"
                   }
                 },
                 premium: false
               }
             }

      user = User |> Repo.get(user.id) |> Repo.preload([:profile])
      assert user.profile.hidden? == false
      assert user.onboarded_at
    end

    test "with support story", %{socket: socket, user: user} do
      assert {:ok, %{support_story: story}, _socket} = join(socket, "profile:" <> user.id)
      assert [%{"background" => _background, "labels" => _labels, "size" => _size}] = story
    end
  end

  describe "upload-preflight" do
    setup do
      user = onboarded_user()
      {:ok, user: user, socket: connected_socket(user)}
    end

    setup :subscribe_and_join

    test "it works", %{socket: socket} do
      ref = push(socket, "upload-preflight", %{"media" => %{"content-type" => "image/jpeg"}})
      assert_reply(ref, :ok, reply, 1000)

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

  describe "acquisition-channel" do
    setup do
      user = onboarded_user()
      {:ok, user: user, socket: connected_socket(user)}
    end

    setup :subscribe_and_join

    test "it works", %{socket: socket} do
      ref = push(socket, "acquisition-channel", %{"channel" => "instagram"})
      assert_reply(ref, :ok)

      ref = push(socket, "acquisition-channel", %{"channel" => "friends"})
      assert_reply(ref, :ok)
    end
  end
end
