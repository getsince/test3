defmodule T.Music do
  @moduledoc "apple music api client"

  def token do
    config = Application.get_env(:t, __MODULE__)
    token(config)
  end

  def token(config) do
    key = Keyword.fetch!(config, :key)
    team_id = Keyword.fetch!(config, :team_id)
    key_id = Keyword.fetch!(config, :key_id)

    signer = Joken.Signer.create("ES256", %{"pem" => key}, %{"kid" => key_id})

    claims = Joken.Config.default_claims(iss: team_id, iat: :os.system_time(:seconds))
    {:ok, token, _claims} = Joken.generate_and_sign(claims, %{}, signer)

    token
  end

  @doc false
  def fetch do
    url = "https://api.music.apple.com/v1/catalog/us/songs/203709340"

    %HTTPoison.Response{body: body, status_code: 200} =
      HTTPoison.get!(url, [{"Authorization", "Bearer #{token()}"}])

    Jason.decode!(body)
  end
end
