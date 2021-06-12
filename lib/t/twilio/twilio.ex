defmodule T.Twilio do
  @moduledoc "Basic Twilio client"

  def creds do
    config = Application.get_env(:t, __MODULE__)
    Map.new(config)
  end

  # TODO cache
  # TODO lower ttl
  # TODO don't leak secrets to logs
  if Mix.env() == :test do
    def ice_servers do
      # TODO
      %{}
    end
  else
    def ice_servers do
      %{account_sid: account_sid, key_sid: key_sid, auth_token: auth_token} = creds()

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
end
