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

      assert %{"id" => user_id, "token" => token} = json_response(conn, 200)
      assert Accounts.get_user!(user_id)
      raw_token = Accounts.UserToken.raw_token(token)

      assert %Accounts.User{id: ^user_id} =
               Accounts.get_user_by_session_token(raw_token, "mobile")
    end
  end
end
