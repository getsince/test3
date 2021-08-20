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
               "story" => [],
               "gender" => nil,
               "name" => nil,
               "gender_preference" => nil,
               "latitude" => nil,
               "longitude" => nil
             }

      assert Accounts.get_user!(user_id)
      raw_token = Accounts.UserToken.raw_token(token)

      assert %Accounts.User{id: ^user_id} =
               user = Accounts.get_user_by_session_token(raw_token, "mobile")

      # existing user (TODO split test)
      user = Repo.preload(user, :profile)

      assert {:ok, _profile} =
               Accounts.onboard_profile(user.profile, %{
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
               "story" => [],
               "gender" => "M",
               "name" => "that",
               "gender_preference" => nil,
               "latitude" => 50.0,
               "longitude" => 50.0
             }
    end
  end
end
