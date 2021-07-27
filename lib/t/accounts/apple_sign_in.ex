defmodule T.Accounts.AppleSignIn do
  @moduledoc false
  alias JOSE.{JWS, JWT}

  @apple_keys_url "https://appleid.apple.com/auth/keys"

  @spec fields_from_token(String.t(), [map()]) ::
          {:ok, %{id: String.t(), email: String.t(), is_private_email: boolean}}
          | {:error, :invalid_key_id | :invalid_token}
  def fields_from_token(id_token, keys \\ fetch_keys()) do
    with {:key, key} when not is_nil(key) <- {:key, key_for_token(keys, id_token)},
         {:verify, {:ok, fields}} <- {:verify, verify_token(key, id_token)} do
      {:ok, extract_user_fields(fields)}
    else
      {:key, nil} -> {:error, :invalid_key_id}
      {:verify, _} -> {:error, :invalid_token}
    end
  end

  defp extract_user_fields(fields) do
    %{
      # TODO verify bundle <> team id? aud == "com.example.apple-samplecode.juiceP85PYLD8U2"
      "aud" => _aud,
      "email" => email,
      "is_private_email" => is_private_email,
      "iss" => "https://appleid.apple.com",
      "sub" => user_id
    } = fields

    %{id: user_id, email: email, is_private_email: is_private_email == "true"}
  end

  @spec key_for_token([map()], String.t()) :: map() | nil
  def key_for_token(keys, id_token) do
    %JWS{fields: %{"kid" => wanted}} = JWT.peek_protected(id_token)
    Enum.find(keys, fn %{"kid" => kid} -> wanted == kid end)
  end

  def verify_token(key, id_token) do
    case JWT.verify(key, id_token) do
      {true, %JWT{fields: fields}, _jws} -> {:ok, fields}
      _other -> :error
    end
  end

  # TODO can cache? probably not
  # TODO add retries then
  @spec fetch_keys :: [map()]
  def fetch_keys do
    req = Finch.build(:get, @apple_keys_url)
    {:ok, %Finch.Response{status: 200, body: body}} = Finch.request(req, T.Finch)
    %{"keys" => keys} = Jason.decode!(body)
    keys
  end
end
