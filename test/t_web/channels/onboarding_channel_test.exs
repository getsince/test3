defmodule TWeb.OnboardingChannelTest do
  use TWeb.ChannelCase, async: true
  alias T.Accounts
  alias Accounts.User

  setup do
    {:ok, %User{} = user} = Accounts.register_user(%{phone_number: phone_number()})
    token = user |> Accounts.generate_user_session_token() |> Base.encode64(padding: false)
    {:ok, socket} = connect(TWeb.UserSocket, %{"token" => token}, %{})
    {:ok, user: Repo.preload(user, :profile), socket: socket}
  end

  describe "join" do
    test "with empty profile", %{socket: socket, user: user} do
      {:ok, reply, _socket} = subscribe_and_join(socket, "onboarding:" <> user.id, %{})

      assert reply == %{
               profile: %{
                 alcohol: nil,
                 birthdate: nil,
                 books: [],
                 cuisines: [],
                 currently_studying: [],
                 first_date_idea: nil,
                 free_form: nil,
                 gender: nil,
                 height: nil,
                 home_city: nil,
                 interests: [],
                 job: nil,
                 languages: [],
                 major: nil,
                 most_important_in_life: nil,
                 movies: [],
                 music: [],
                 musical_instruments: [],
                 name: nil,
                 occupation: nil,
                 pets: [],
                 photos: [],
                 smoking: nil,
                 social_networks: [],
                 sports: [],
                 tv_shows: [],
                 university: nil
               }
             }
    end

    @tag skip: true
    test "with invalid user id", %{socket: socket} do
      assert {:error, %{reason: "join crashed"}} =
               subscribe_and_join(socket, "onboarding:" <> Ecto.UUID.generate(), %{})
    end

    test "with partially filled profile", %{socket: socket, user: user} do
      {:ok, _profile} =
        Accounts.update_profile(user.profile, %{"name" => "Jojaresum", "photos" => ["photo.jpg"]})

      assert {:ok, %{profile: %{name: "Jojaresum", photos: ["photo.jpg"]}}, _socket} =
               subscribe_and_join(socket, "onboarding:" <> user.id, %{})
    end
  end

  defp subscribe_and_join(%{socket: socket, user: user}) do
    {:ok, _reply, socket} = subscribe_and_join(socket, "onboarding:" <> user.id, %{})
    {:ok, socket: socket}
  end

  describe "upload-preflight" do
    setup :subscribe_and_join

    test "it works", %{socket: socket} do
      ref = push(socket, "upload-preflight", %{"content-type" => "image/jpeg"})
      assert_reply ref, :ok, reply

      assert %{
               fields: %{
                 "acl" => "private",
                 "content-type" => "image/jpeg",
                 "key" => key,
                 "policy" => _policy,
                 "x-amz-algorithm" => "AWS4-HMAC-SHA256",
                 "x-amz-credential" => "AWS_ACCESS_KEY_ID/20201231/eu-central-1/s3/aws4_request",
                 "x-amz-date" => _date,
                 "x-amz-server-side-encryption" => "AES256",
                 "x-amz-signature" => _signature
               },
               key: key,
               url: "https://pretend-this-is-real.s3.amazonaws.com"
             } = reply
    end
  end

  describe "photos" do
    setup :subscribe_and_join

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

    test "with complete profile", %{socket: socket} do
      # TODO
    end
  end
end
