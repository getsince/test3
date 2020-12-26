defmodule TWeb.AuthControllerTest do
  use TWeb.ConnCase, async: true
  alias T.Accounts

  describe "use_session?=false" do
    test "it works", %{conn: conn} do
      phone_number = "+79777777777"
      code = PasswordlessAuth.generate_code(phone_number)

      conn =
        post(conn, "/api/auth/verify-phone-number", %{
          use_session?: false,
          code: code,
          phone_number: phone_number
        })

      assert %{"id" => user_id, "token" => token} = json_response(conn, 200)
      assert Accounts.get_user!(user_id)

      assert %Accounts.User{id: ^user_id} =
               Accounts.get_user_by_session_token(Base.url_decode64!(token, padding: false))

      assert %{"me" => ^user_id, "next" => "onboarding", "token" => _token} =
               build_conn()
               |> put_req_header("accept", "application/json")
               |> put_req_header("authorization", "Bearer #{token}")
               |> get("/api/me")
               |> json_response(200)

      assert %{
               "profile" => %{
                 "alcohol" => nil,
                 "birthdate" => nil,
                 "books" => [],
                 "cuisines" => [],
                 "currently_studying" => [],
                 "first_date_idea" => nil,
                 "free_form" => nil,
                 "gender" => nil,
                 "height" => nil,
                 "home_city" => nil,
                 "interests" => [],
                 "job" => nil,
                 "languages" => [],
                 "major" => nil,
                 "most_important_in_life" => nil,
                 "movies" => [],
                 "music" => [],
                 "musical_instruments" => [],
                 "name" => nil,
                 "occupation" => nil,
                 "pets" => [],
                 "photos" => [],
                 "smoking" => nil,
                 "social_networks" => [],
                 "sports" => [],
                 "tv_shows" => [],
                 "university" => nil
               }
             } =
               build_conn()
               |> put_req_header("accept", "application/json")
               |> put_req_header("authorization", "Bearer #{token}")
               |> get("/api/profile")
               |> json_response(200)
    end
  end
end
