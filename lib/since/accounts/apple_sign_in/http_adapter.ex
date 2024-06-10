defmodule Since.Accounts.AppleSignIn.HTTPAdapter do
  @moduledoc false
  @behaviour T.Accounts.AppleSignIn.Adapter

  @apple_keys_url "https://appleid.apple.com/auth/keys"

  # TODO can cache? probably not
  # TODO add retries then
  @impl true
  def fetch_keys do
    req = Finch.build(:get, @apple_keys_url)
    {:ok, %Finch.Response{status: 200, body: body}} = Finch.request(req, T.Finch)
    %{"keys" => keys} = :json.decode(body)
    keys
  end
end
