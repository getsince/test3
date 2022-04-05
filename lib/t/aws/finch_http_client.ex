# TODO configure aws client to use this http client
defmodule AWS.FinchHTTPClient do
  @moduledoc false
  @behaviour AWS.HTTPClient

  @impl true
  def request(method, url, body, headers, options) do
    req = Finch.build(method, url, headers, body)

    case Finch.request(req, T.Finch, options) do
      {:ok, %Finch.Response{status: status, body: body, headers: headers}} ->
        {:ok, %{status_code: status, headers: headers, body: body}}

      {:error, _error} = error ->
        error
    end
  end
end
