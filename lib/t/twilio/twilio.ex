defmodule T.Twilio do
  @moduledoc "Basic Twilio client"

  def creds do
    config = Application.get_env(:t, __MODULE__)
    Map.new(config)
  end

  # TODO cache
  # TODO lower ttl
  # TODO don't leak secrets to logs
  def ice_servers do
    %{account_sid: account_sid, key_sid: key_sid, auth_token: auth_token} = creds()

    url = "https://api.twilio.com/2010-04-01/Accounts/#{account_sid}/Tokens.json"
    body = ""
    headers = []
    opts = [hackney: [basic_auth: {key_sid, auth_token}]]

    %HTTPoison.Response{status_code: 201, body: body} = HTTPoison.post!(url, body, headers, opts)
    %{"ice_servers" => ice_servers} = Jason.decode!(body)
    ice_servers
  end
end
