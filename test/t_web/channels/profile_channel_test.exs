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
               gender_preference: nil,
               story: [],
               gender: nil,
               name: nil
             }
    end
  end

  describe "join with onboarded profile" do
    setup do
      user = registered_user()
      {:ok, user: user, socket: connected_socket(user)}
    end

    test "with invalid user id", %{socket: socket} do
      assert {:error, %{"error" => "forbidden"}} =
               join(socket, "profile:" <> Ecto.UUID.generate())
    end

    test "with partially filled profile", %{socket: socket, user: user} do
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
               gender: nil,
               gender_preference: nil,
               latitude: nil,
               longitude: nil,
               user_id: user.id
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
      assert_reply ref, :error, reply, 1000

      assert reply == %{
               profile: %{
                 gender: ["can't be blank"],
                 name: ["can't be blank"],
                 location: ["can't be blank"]
               }
             }

      ref =
        push(socket, "submit", %{
          "profile" => %{
            "name" => "hey that's me CLARISA",
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
                 gender: "F",
                 name: "hey that's me CLARISA"
               }
             }

      user = User |> Repo.get(user.id) |> Repo.preload([:profile])
      assert user.profile.hidden? == false
      assert user.onboarded_at
    end

    test "profile-editor-tutorial", %{socket: socket} do
      ref = push(socket, "profile-editor-tutorial", %{})
      assert_reply ref, :ok, reply, 1000

      assert reply == %{
               story: [
                 %{
                   "background" => %{"color" => "#F97EB9"},
                   "labels" => [
                     %{
                       "center" => [142.3333282470703, 317.8333282470703],
                       "rotation" => 0,
                       "size" => [247.293, 44.052],
                       "value" => "добавили твоё имя 👆"
                     },
                     %{
                       "answer" => "<REPLACE>",
                       "center" => [221.00001525878906, 193.16668701171875],
                       "question" => "name",
                       "rotation" => 0,
                       "size" => [148.403, 56.516],
                       "value" => "<REPLACE>"
                     },
                     %{
                       "center" => [260.3333282470702, 611.1666870117186],
                       "rotation" => -25.07355455145478,
                       "size" => [181.71391118062405, 107.80452788116632],
                       "value" => "перелистни\nна следующую\nстраницу 👉👉"
                     }
                   ],
                   "size" => [428, 926]
                 },
                 %{
                   "background" => %{"color" => "#5E50FC"},
                   "labels" => [
                     %{
                       "answer" => "Москва",
                       "center" => [101.99999999999994, 255.66665649414062],
                       "question" => "city",
                       "rotation" => 0,
                       "size" => [142.66666666666666, 142.66666666666666],
                       "url" =>
                         "https://d4321.cloudfront.net/%D0%9C%D0%BE%D1%81%D0%BA%D0%B2%D0%B0?d=20c94e76042e85ddca6459853c9bb116",
                       "value" => "Москва"
                     },
                     %{
                       "center" => [297.6666564941406, 185.83334350585938],
                       "rotation" => -22.602836861171024,
                       "size" => [171.84924426813305, 47.188753122933925],
                       "value" => "👈 это стикер"
                     },
                     %{
                       "center" => [207, 695.5],
                       "rotation" => 0,
                       "size" => [293.581, 44.052],
                       "value" => "перетащи меня 👇 и удали"
                     }
                   ],
                   "size" => [428, 926]
                 }
               ]
             }
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
end
