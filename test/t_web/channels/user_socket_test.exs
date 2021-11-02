defmodule TWeb.UserSocketTest do
  use TWeb.ChannelCase, async: true
  alias TWeb.UserSocket
  alias T.Accounts

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

      assert {:ok, _socket} = connect(UserSocket, %{"token" => token}, %{})

      token = Accounts.UserToken |> where(user_id: ^user.id) |> Repo.one()

      %Accounts.UserToken{version: version} = token

      assert version == nil
    end

    test "with valid token and version", %{user: user} do
      token =
        user
        |> Accounts.generate_user_session_token("mobile")
        |> Accounts.UserToken.encoded_token()

      assert {:ok, _socket} = connect(UserSocket, %{"token" => token, "version" => "2.2.2"}, %{})

      token = Accounts.UserToken |> where(user_id: ^user.id) |> Repo.one()

      %Accounts.UserToken{version: version} = token

      assert version == "ios/2.2.2"
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

    {:ok, socket1} = connect(UserSocket, %{"token" => token1}, %{})
    {:ok, socket2} = connect(UserSocket, %{"token" => token2}, %{})

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
