defmodule T.APNS do
  @moduledoc "Finch-based APNS client."
  alias __MODULE__

  @finch T.Finch

  def push(notification, token \\ APNS.Token.current_token()) do
    req = APNS.Request.build_finch_request(notification, token)

    case Finch.request(req, @finch) do
      {:ok, %Finch.Response{status: 200}} -> :ok
      {:ok, %Finch.Response{status: 429, body: body}} -> {:error, 429, Jason.decode!(body)}
      {:error, _reason} = error -> error
    end
  end
end
