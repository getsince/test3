defmodule T.Accounts.RegistrationTest do
  use T.DataCase, async: true
  alias T.Accounts
  alias T.Accounts.PasswordlessAuth

  describe "with phone number" do
    test "with a valid one" do
      # request SMS
      phone_number = "+79777777777"
      code = PasswordlessAuth.generate_code(phone_number)

      # first, invalid code
      assert {:error, :incorrect_code} ==
               Accounts.login_or_register_user_with_phone(phone_number, "111")

      # ah ok, here's valid
      assert {:ok,
              %Accounts.User{
                blocked_at: nil,
                onboarded_at: nil,
                phone_number: ^phone_number,
                profile: %Accounts.Profile{
                  hidden?: true,
                  last_active: last_active,
                  gender: nil,
                  name: nil
                }
              }} = Accounts.login_or_register_user_with_phone(phone_number, code)

      assert last_active
    end
  end
end
