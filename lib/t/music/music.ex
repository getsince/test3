defmodule T.Music do
  @moduledoc "apple music api client"

  @adapter Application.compile_env!(:t, [__MODULE__, :adapter])

  @callback get_song(binary) :: map

  def token do
    config = Application.get_env(:t, __MODULE__)
    token(config)
  end

  # TODO cache
  def token(config) do
    key = Keyword.fetch!(config, :key)
    team_id = Keyword.fetch!(config, :team_id)
    key_id = Keyword.fetch!(config, :key_id)

    signer = Joken.Signer.create("ES256", %{"pem" => key}, %{"kid" => key_id})

    claims = Joken.Config.default_claims(iss: team_id, iat: :os.system_time(:seconds))
    {:ok, token, _claims} = Joken.generate_and_sign(claims, %{}, signer)

    token
  end

  def get_song(id) do
    @adapter.get_song(id)
  end
end
