defmodule SinceWeb.UserSocketTest do
  use SinceWeb.ChannelCase, async: true
  alias SinceWeb.UserSocket
  alias Since.Accounts
  use Oban.Testing, repo: Since.Repo

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

      assert {:error, :unsupported_version} =
               connect(UserSocket, %{"token" => token}, connect_info: %{})

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
             ] = all_enqueued(worker: Since.PushNotifications.DispatchJob)
    end

    test "with valid token and version", %{user: user} do
      token =
        user
        |> Accounts.generate_user_session_token("mobile")
        |> Accounts.UserToken.encoded_token()

      assert {:ok, _socket} =
               connect(UserSocket, %{"token" => token, "version" => "7.0.0"}, connect_info: %{})

      %Accounts.UserToken{version: version} =
        Accounts.UserToken |> where(user_id: ^user.id) |> Repo.one()

      assert version == "ios/7.0.0"
    end

    test "without token" do
      assert :error == connect(UserSocket, %{}, connect_info: %{})
    end

    test "with invalid token" do
      user = insert(:user)

      # built but not persisted to DB
      {token, %Accounts.UserToken{context: "mobile", token: token}} =
        Accounts.UserToken.build_token(user, "mobile")

      assert {:error, :invalid_token} ==
               connect(
                 UserSocket,
                 %{"token" => Accounts.UserToken.encoded_token(token)},
                 connect_info: %{}
               )
    end

    test "blocked" do
      user = insert(:user)

      Accounts.User
      |> where(id: ^user.id)
      |> update([u], set: [blocked_at: fragment("now()")])
      |> Repo.update_all([])

      token =
        user
        |> Accounts.generate_user_session_token("mobile")
        |> Accounts.UserToken.encoded_token()

      assert {:error, :blocked_user} ==
               connect(
                 UserSocket,
                 %{"token" => Accounts.UserToken.encoded_token(token)},
                 connect_info: %{}
               )
    end

    test "with location" do
      user = onboarded_user()

      token =
        user
        |> Accounts.generate_user_session_token("mobile")
        |> Accounts.UserToken.encoded_token()

      assert {:ok, socket} =
               connect(
                 UserSocket,
                 %{"token" => token, "version" => "7.0.0", "location" => [35.755516, 27.615040]},
                 connect_info: %{}
               )

      assert socket.assigns.location == %Geo.Point{coordinates: {27.61504, 35.755516}, srid: 4326}

      profile = Accounts.Profile |> where(user_id: ^user.id) |> Repo.one()

      assert profile.location == %Geo.Point{coordinates: {27.61504, 35.755516}, srid: 4326}
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

    {:ok, socket1} =
      connect(UserSocket, %{"token" => token1, "version" => "7.0.0"}, connect_info: %{})

    {:ok, socket2} =
      connect(UserSocket, %{"token" => token2, "version" => "7.0.0"}, connect_info: %{})

    socket_id1 = UserSocket.id(socket1)
    socket_id2 = UserSocket.id(socket2)

    @endpoint.subscribe(socket_id1)
    @endpoint.subscribe(socket_id2)

    assert :ok = SinceWeb.UserAuth.log_out_mobile_user(token1)

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
