defmodule AppStore.Token do
  @moduledoc false

  require Logger

  use GenServer
  alias JOSE.{JWK, JWS, JWT}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec current_env_and_token() :: {atom(), String.t()}
  def current_env_and_token() do
    lookup_env_and_token() || refresh_token()
  end

  @spec lookup_env_and_token() :: {atom(), String.t()} | nil
  defp lookup_env_and_token() do
    case :ets.first(__MODULE__) do
      [{env, token}] -> if token_age(token) < 59 * 60, do: {env, token}
      _ -> nil
    end
  end

  @spec find_app_store_key() :: map | nil
  defp find_app_store_key() do
    Application.fetch_env!(:t, AppStore)
    |> Keyword.fetch!(:key)
  end

  @spec refresh_token() :: {atom(), String.t()}
  defp refresh_token() do
    if key = find_app_store_key() do
      GenServer.call(__MODULE__, {:refresh_token, key})
    else
      raise ArgumentError, "unknown key"
    end
  end

  @impl true
  def init(_opts) do
    __MODULE__ = :ets.new(__MODULE__, [:named_table])
    {:ok, nil}
  end

  @impl true
  def handle_call({:refresh_token, key}, _from, state) do
    %{key: key, key_id: key_id, issuer_id: issuer_id, topic: topic, env: env} = key

    case lookup_env_and_token() do
      {env, token} ->
        {:reply, {env, token}, state}

      nil ->
        token = generate_jwt_token(key, key_id, issuer_id, topic)
        :ets.insert(__MODULE__, {env, token})
        {:reply, {env, token}, state}
    end
  end

  # token generation

  defp generate_jwt_token(key, key_id, issuer_id, topic, now \\ :os.system_time(:seconds)) do
    jwk = JWK.from_pem(key)
    jws = JWS.from_map(%{"alg" => "ES256", "kid" => key_id, "typ" => "JWT"})

    payload = %{
      "aud" => "appstoreconnect-v1",
      "iss" => issuer_id,
      "iat" => now,
      "exp" => now + 3600,
      "bid" => topic
    }

    jwt = JWT.sign(jwk, jws, payload)

    {_, token} = JWS.compact(jwt)
    token
  end

  defp token_age(token, now \\ :os.system_time(:second)) when is_binary(token) do
    %JWT{fields: %{"iat" => iat}} = JWT.peek(token)
    now - iat
  end
end
