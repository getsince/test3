defmodule AppStore.Token do
  @moduledoc false

  require Logger

  use GenServer
  alias JOSE.{JWK, JWS, JWT}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec current_token(String.t(), AppStore.env()) :: String.t()
  def current_token(topic, env) do
    lookup_token(topic, env) || refresh_token(topic, env)
  end

  @spec lookup_token(String.t(), AppStore.env()) :: String.t() | nil
  defp lookup_token(topic, env) do
    case :ets.lookup(__MODULE__, {topic, env}) do
      [{_, token}] -> if token_age(token) < 59 * 60, do: token
      [] -> nil
    end
  end

  @spec find_app_store_key(String.t(), AppStore.env()) :: map | nil
  defp find_app_store_key(topic, env) do
    Application.fetch_env!(:t, AppStore)
    |> Keyword.fetch!(:keys)
    |> Enum.find(fn %{topic: t, env: e} -> topic == t and env == e end)
  end

  @spec refresh_token(String.t(), AppStore.env()) :: String.t()
  defp refresh_token(topic, env) do
    if key = find_app_store_key(topic, env) do
      GenServer.call(__MODULE__, {:refresh_token, key})
    else
      raise ArgumentError, "unknown key for topic #{inspect(topic)} and env #{inspect(env)}"
    end
  end

  @impl true
  def init(_opts) do
    __MODULE__ = :ets.new(__MODULE__, [:named_table])
    {:ok, nil}
  end

  @impl true
  def handle_call({:refresh_token, key}, _from, state) do
    %{key: key, key_id: key_id, env: env, issuer_id: issuer_id, topic: topic} = key

    if token = lookup_token(topic, env) do
      {:reply, token, state}
    else
      token = generate_jwt_token(key, key_id, issuer_id, topic)
      :ets.insert(__MODULE__, {{topic, env}, token})
      {:reply, token, state}
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

    Logger.warn(payload)

    jwt = JWT.sign(jwk, jws, payload)

    {_, token} = JWS.compact(jwt)
    token
  end

  defp token_age(token, now \\ :os.system_time(:second)) when is_binary(token) do
    %JWT{fields: %{"iat" => iat}} = JWT.peek(token)
    now - iat
  end
end
