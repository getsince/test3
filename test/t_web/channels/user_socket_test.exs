defmodule TWeb.UserSocketTest do
  use TWeb.ChannelCase, async: true
  alias TWeb.UserSocket
  alias T.Accounts
  use Oban.Testing, repo: T.Repo

  import Ecto.Query

  setup do
    {:ok, user: insert(:user)}
  end

  describe "connect" do
    test "with valid token and no version", %{user: user} do
      token =
        user
        |> Accounts.generate_user_session_token("mobile")
        |> Accounts.UserToken.encoded_token()

      assert {:error, :unsupported_version} = connect(UserSocket, %{"token" => token}, %{})

      %Accounts.UserToken{version: version} =
        Accounts.UserToken |> where(user_id: ^user.id) |> Repo.one()

      assert version == nil

      user_id = user.id

      assert [
               %Oban.Job{
                 args: %{
                   "user_id" => ^user_id,
                   "type" => "upgrade_app"
                 }
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)
    end

    test "with valid token and version", %{user: user} do
      token =
        user
        |> Accounts.generate_user_session_token("mobile")
        |> Accounts.UserToken.encoded_token()

      assert {:ok, _socket} = connect(UserSocket, %{"token" => token, "version" => "6.0.0"}, %{})

      %Accounts.UserToken{version: version} =
        Accounts.UserToken |> where(user_id: ^user.id) |> Repo.one()

      assert version == "ios/6.0.0"
    end

    test "without token" do
      assert :error == connect(UserSocket, %{}, %{})
    end

    test "with invalid token" do
      user = insert(:user)

      # built but not persisted to DB
      {token, %Accounts.UserToken{context: "mobile", token: token}} =
        Accounts.UserToken.build_token(user, "mobile")

      assert :error ==
               connect(UserSocket, %{"token" => Accounts.UserToken.encoded_token(token)}, %{})
    end
  end

  test "disconnected on log out", %{user: user} do
    token1 =
      user
      |> Accounts.generate_user_session_token("mobile")
      |> Accounts.UserToken.encoded_token()

    token2 =
      user
      |> Accounts.generate_user_session_token("mobile")
      |> Accounts.UserToken.encoded_token()

    {:ok, socket1} = connect(UserSocket, %{"token" => token1, "version" => "6.0.0"}, %{})
    {:ok, socket2} = connect(UserSocket, %{"token" => token2, "version" => "6.0.0"}, %{})

    socket_id1 = UserSocket.id(socket1)
    socket_id2 = UserSocket.id(socket2)

    @endpoint.subscribe(socket_id1)
    @endpoint.subscribe(socket_id2)

    assert :ok = TWeb.UserAuth.log_out_mobile_user(token1)

    assert_receive %Phoenix.Socket.Broadcast{
      event: "disconnect",
      payload: %{},
      topic: ^socket_id1
    }

    refute_receive %Phoenix.Socket.Broadcast{
      event: "disconnect",
      payload: %{},
      topic: ^socket_id2
    }
  end
end
