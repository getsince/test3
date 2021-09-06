defmodule T.Twilio.HTTP do
  @moduledoc false
  @behaviour T.Twilio.Adapter
  alias T.Twilio

  # TODO lower ttl (24h right now)
  # TODO don't leak secrets to logs
  @impl true
  def fetch_ice_servers do
    %{account_sid: account_sid, key_sid: key_sid, auth_token: auth_token} = Twilio.creds()

    url = "https://api.twilio.com/2010-04-01/Accounts/#{account_sid}/Tokens.json"
    headers = [{"Authorization", basic_auth(key_sid, auth_token)}]

    req = Finch.build(:post, url, headers)
    {:ok, %Finch.Response{status: 201, body: body}} = Finch.request(req, T.Finch)

    %{"ice_servers" => ice_servers} = Jason.decode!(body)
    ice_servers
  end

  defp basic_auth(username, password) do
    "Basic " <> Base.encode64(username <> ":" <> password)
  end
end
