defmodule T.Spotify do
  @moduledoc "spotify api client"

  use GenServer

  @spotify_token_url "https://accounts.spotify.com/api/token"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec current_token :: {:ok, String.t()} | :error
  def current_token do
    token = lookup_token() || refresh_token()

    if token do
      {token, expiration_time} = token

      expires_in = expiration_time - :os.system_time(:second)

      {:ok, %{token: token, expires_in: expires_in}}
    else
      :error
    end
  end

  @spec lookup_token :: {String.t(), integer()} | nil
  defp lookup_token do
    case :ets.lookup(__MODULE__, :token) do
      [{_, token}] -> if token_still_valid(token), do: token
      [] -> nil
    end
  end

  defp find_spotify_key do
    config = Application.fetch_env!(:t, T.Spotify)
    client_id = Keyword.fetch!(config, :client_id)
    client_secret = Keyword.fetch!(config, :client_secret)

    %{client_id: client_id, client_secret: client_secret}
  end

  @spec refresh_token :: String.t() | nil
  defp refresh_token do
    key = find_spotify_key()
    GenServer.call(__MODULE__, {:refresh_token, key})
  end

  @impl true
  def init(_opts) do
    __MODULE__ = :ets.new(__MODULE__, [:named_table])
    {:ok, nil}
  end

  @impl true
  def handle_call({:refresh_token, key}, _from, state) do
    %{client_id: client_id, client_secret: client_secret} = key

    if token = lookup_token() do
      {:reply, token, state}
    else
      token = request_token(client_id, client_secret)
      :ets.insert(__MODULE__, {:token, token})
      {:reply, token, state}
    end
  end

  defp token_still_valid({_token, expiration_time}, now \\ :os.system_time(:second)) do
    expiration_time > now + 60
  end

  @spec request_token(String.t(), String.t(), integer) :: {String.t(), integer()} | nil
  defp request_token(client_id, client_secret, now \\ :os.system_time(:second)) do
    auth_key = Base.encode64(client_id <> ":" <> client_secret)

    headers = [
      {"authorization", "Basic " <> auth_key},
      {"content-type", "application/x-www-form-urlencoded"}
    ]

    body = "grant_type=client_credentials"

    req = Finch.build(:post, @spotify_token_url, headers, body)

    case Finch.request(req, T.Finch, receive_timeout: 5000) do
      {:ok, %Finch.Response{status: _status, body: body, headers: _headers}} ->
        case Jason.decode(body) do
          {:ok, %{"access_token" => token, "expires_in" => expires_in}} ->
            {token, now + expires_in}

          {:ok, extra} ->
            Sentry.capture_message("failed to decode spotify token", extra: extra)
            nil

          {:error, extra} ->
            Sentry.capture_message("failed to decode spotify token", extra: extra)
            nil
        end

      {:error, reply} ->
        Sentry.capture_message("failed to receive spotify token", extra: reply)
        nil
    end
  end
end
