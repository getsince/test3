defmodule TWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "discover:*", TWeb.DiscoverChannel
  channel "match:*", TWeb.MatchChannel
  channel "profile:*", TWeb.ProfileChannel
  channel "notification:*", TWeb.NotificationChannel
  channel "onboarding:*", TWeb.OnboardingChannel

  @impl true
  def connect(%{"token" => token}, socket, connect_info) do
    IO.inspect(connect_info, label: "connect info")
    IO.inspect(token, label: "token")

    case verify_token(socket, token) do
      {:ok, user} -> {:ok, assign(socket, user: user)}
      {:error, _reason} -> :error
    end

    # {:ok, put_in(socket.private[:connect_info], connect_info)}
  end

  defp verify_token(socket, token) do
    case Phoenix.Token.verify(socket, "Urm6JRcI", token, max_age: 86400) do
      {:ok, user_id} -> {:ok, T.Accounts.get_user!(user_id)}
      {:error, _reason} = error -> error
    end
  end

  @impl true
  def id(socket) do
    # TODO per session
    "user_socket:#{socket.assigns.user.id}"
  end
end
