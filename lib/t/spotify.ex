defmodule T.Spotify do
  @moduledoc "spotify api client"

  @spotify_token_url "https://accounts.spotify.com/api/token"

  def token do
    config = Application.get_env(:t, __MODULE__)
    token(config)
  end

  # TODO cache?
  def token(config) do
    client_id = Keyword.fetch!(config, :client_id)
    client_secret = Keyword.fetch!(config, :client_secret)

    auth_key = Base.encode64(client_id <> ":" <> client_secret)

    headers = [
      {"authorization", "basic " <> auth_key},
      {"content-type", "application/x-www-form-urlencoded"}
    ]

    body = "grant_type=client_credentials"

    req = Finch.build(:post, @spotify_token_url, headers, body)

    case Finch.request(req, T.Finch, receive_timeout: 5000) do
      {:ok, %Finch.Response{status: _status, body: body, headers: _headers}} ->
        case Jason.decode(body) do
          {:ok, %{"access_token" => token}} -> {:ok, %{token: token}}
          {:ok, %{"error" => error}} -> {:error, %{reason: error}}
          {:ok, body} -> {:error, %{reason: body}}
          {:error, error} -> {:error, %{reason: error}}
        end

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end
end
