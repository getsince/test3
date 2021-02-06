defmodule T.Accounts.APNSTest do
  use T.DataCase, async: true
  alias T.Accounts

  describe "save_apns_device_id/3" do
    setup do
      user = insert(:user)

      token =
        user
        |> Accounts.generate_user_session_token("mobile")
        |> Accounts.UserToken.encoded_token()

      {:ok, user: user, token: token}
    end

    test "with valid user and token", %{user: user, token: token} do
      assert :ok == Accounts.save_apns_device_id(user.id, token, "ABABABABA")
      assert [%Accounts.APNSDevice{device_id: "ABABABABA"}] = Repo.all(Accounts.APNSDevice)
      # duplicate is overriden
      assert :ok == Accounts.save_apns_device_id(user.id, token, "BCBCBCBC")
      assert [%Accounts.APNSDevice{device_id: "BCBCBCBC"}] = Repo.all(Accounts.APNSDevice)
    end

    test "user can switch account", %{user: user, token: token} do
      # save device id for current user and session
      assert :ok == Accounts.save_apns_device_id(user.id, token, "ABABABABA")
      assert [%Accounts.APNSDevice{device_id: "ABABABABA"}] = Repo.all(Accounts.APNSDevice)
      # on log out the apns token is deleted, so user can login and store the token again
      assert :ok == Accounts.delete_session_token(token, "mobile")
      assert [] == Repo.all(Accounts.APNSDevice)
    end
  end
end
