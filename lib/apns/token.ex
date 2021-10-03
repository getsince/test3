defmodule T.APNS.Token do
  @moduledoc false
  use GenServer
  alias JOSE.{JWK, JWS, JWT}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

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

  @spec current_token(String.t(), :dev | :prod) :: String.t()
  def current_token(topic, env) do
    lookup_token(topic, env) || refresh_token(topic, env)
  end

  @spec lookup_token(String.t(), :dev | :prod) :: String.t() | nil
  defp lookup_token(topic, env) do
    case :ets.lookup(__MODULE__, {topic, env}) do
      [{_, token}] -> if token_age(token) < 59 * 60, do: token
      [] -> nil
    end
  end

  @spec find_apns_key(String.t(), :dev | :prod) :: map | nil
  defp find_apns_key(topic, env) do
    config = Application.get_env(:t, T.APNS)
    keys = Keyword.fetch!(config, :keys)
    Enum.find(keys, fn %{topic: t, env: e} -> topic == t and env == e end)
  end

  @spec refresh_token(String.t(), :dev | :prod) :: String.t()
  defp refresh_token(topic, env) do
    if key = find_apns_key(topic, env) do
      GenServer.call(__MODULE__, {:refresh_token, key})
    else
      raise ArgumentError, "unknown key for topic #{topic} and env #{env}"
    end
  end

  @impl true
  def init(_opts) do
    __MODULE__ = :ets.new(__MODULE__, [:named_table])
    {:ok, nil}
  end

  @impl true
  def handle_call({:refresh_token, key}, _from, state) do
    %{key: key, key_id: key_id, env: env, team_id: team_id, topic: topic} = key

    if token = lookup_token(topic, env) do
      {:reply, token, state}
    else
      token = generate_jwt_token(key, key_id, team_id)
      :ets.insert(__MODULE__, {{topic, env}, token})
      {:reply, token, state}
    end
  end
end
