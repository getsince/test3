defmodule T.Sentry.FinchHTTPClient do
  @moduledoc false
  # adapts https://github.com/getsentry/sentry-elixir/blob/master/lib/sentry/hackney_client.ex
  @behaviour Sentry.HTTPClient

  @finch_name T.Sentry.Finch

  @impl true
  def child_spec do
    Supervisor.child_spec({Finch, name: @finch_name}, [])
  end

  @impl true
  def post(url, headers, body) do
    req = Finch.build(:post, url, headers, body)

    case Finch.request(req, @finch_name, receive_timeout: 5000) do
      {:ok, %Finch.Response{status: status, body: body, headers: headers}} ->
        {:ok, status, headers, body}

      {:error, _reason} = failure ->
        failure
    end
  end
end
