defmodule T.FinchHttpClient do
  @moduledoc false
  # adapts https://github.com/ex-aws/ex_aws/blob/master/lib/ex_aws/request/hackney.ex to use finch
  @behaviour ExAws.Request.HttpClient

  def request(method, url, body \\ nil, headers \\ [], http_opts \\ []) do
    req = Finch.build(method, url, headers, body)

    case Finch.request(req, T.Finch, http_opts) do
      {:ok, %Finch.Response{status: status, body: body, headers: headers}} ->
        {:ok, %{status_code: status, headers: headers, body: body}}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end
end
