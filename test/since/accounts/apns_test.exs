defmodule Since.Accounts.APNSTest do
  use Since.DataCase, async: true
  alias Since.Accounts
  alias Since.Accounts.{UserToken, APNSDevice}

  setup do
    user = insert(:user)

    token =
      user
      |> Accounts.generate_user_session_token("mobile")
      |> UserToken.encoded_token()

    {:ok, user: user, token: token}
  end

  describe "save_apns_device_id/3" do
    test "with valid user and token", %{user: user, token: token} do
      assert :ok == Accounts.save_apns_device_id(user.id, token, "ABABABABA")
      assert [%APNSDevice{device_id: "ABABABABA"}] = Repo.all(APNSDevice)
      # duplicate is overriden
      assert :ok == Accounts.save_apns_device_id(user.id, token, "BCBCBCBC")
      assert [%APNSDevice{device_id: "BCBCBCBC"}] = Repo.all(APNSDevice)
    end

    test "user can switch account", %{user: user, token: token} do
      # save device id for current user and session
      assert :ok == Accounts.save_apns_device_id(user.id, token, "ABABABABA")
      assert [%APNSDevice{device_id: "ABABABABA"}] = Repo.all(APNSDevice)
      # on log out the apns token is deleted
      assert :ok == Accounts.delete_session_token(token, "mobile")
      assert [] == Repo.all(APNSDevice)
    end

    test "existing device_id is overwritten", %{user: user, token: token} do
      assert :ok == Accounts.save_apns_device_id(user.id, token, "ABABABABA")
      assert [%APNSDevice{device_id: "ABABABABA"}] = Repo.all(APNSDevice)

      assert :ok == Accounts.save_apns_device_id(user.id, token, "ABABABABA")
      assert [%APNSDevice{device_id: "ABABABABA"}] = Repo.all(APNSDevice)

      # new session token
      new_token =
        user
        |> Accounts.generate_user_session_token("mobile")
        |> UserToken.encoded_token()

      %Accounts.UserToken{id: new_token_id} =
        new_token |> UserToken.token_and_context_query("mobile") |> Repo.one!()

      assert :ok == Accounts.save_apns_device_id(user.id, new_token, "ABABABABA")
      assert [%APNSDevice{device_id: "ABABABABA", token_id: ^new_token_id}] = Repo.all(APNSDevice)
    end
  end
end
