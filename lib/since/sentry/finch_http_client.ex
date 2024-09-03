defmodule Since.Sentry.FinchHTTPClient do
  @moduledoc false
  @behaviour Sentry.HTTPClient

  @impl true
  def post(url, headers, body) do
    req = Finch.build(:post, url, headers, body)

    case Finch.request(req, Since.Finch, receive_timeout: 5000) do
      {:ok, %Finch.Response{status: status, body: body, headers: headers}} ->
        {:ok, status, headers, body}

      {:error, _reason} = failure ->
        failure
    end
  end
end
