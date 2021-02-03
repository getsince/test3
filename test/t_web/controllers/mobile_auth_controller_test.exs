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
                 "https://pretend-this-is-real.s3.amazonaws.com/a",
                 "https://pretend-this-is-real.s3.amazonaws.com/b",
                 "https://pretend-this-is-real.s3.amazonaws.com/c",
                 "https://pretend-this-is-real.s3.amazonaws.com/d"
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
