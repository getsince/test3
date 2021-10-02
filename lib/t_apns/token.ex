defmodule T.APNS.Token do
  @moduledoc false

  alias JOSE.{JWK, JWS, JWT}

  def generate_jwt_token(key, key_id, team_id, now \\ :os.system_time(:seconds)) do
    jwk = JWK.from_pem(key)
    jws = JWS.from_map(%{"alg" => "ES256", "kid" => key_id, "typ" => "JWT"})

    jwt =
      JWT.sign(jwk, jws, %{
        "aud" => "appel",
        "iss" => team_id,
        "nbf" => now,
        "iat" => now,
        "exp" => now + 3600,
        "jti" => generate_jti()
      })

    {_, token} = JWS.compact(jwt)
    token
  end

  def generate_jwt_token(env, now \\ :os.system_time(:seconds)) do
    config = Application.fetch_env!(:t, T.APNS)
    keys = Keyword.fetch!(config, :keys)
    %{key: key, key_identifier: kid, team_id: tid} = Map.fetch!(keys, env)
    generate_jwt_token(key, kid, tid, now)
  end

  def token_age(token, now \\ :os.system_time(:second)) when is_binary(token) do
    %JWT{fields: %{"iat" => iat}} = JWT.peek(token)
    now - iat
  end

  defp generate_jti do
    binary = <<
      System.system_time(:nanosecond)::64,
      :erlang.phash2({node(), self()}, 16_777_216)::24,
      :erlang.unique_integer()::32
    >>

    Base.hex_encode32(binary, case: :lower)
  end
end
