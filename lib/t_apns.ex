defmodule T.APNS do
  @moduledoc "Finch-based APNS client."
  alias __MODULE__

  @finch T.Finch

  def push(notification) do
    notification
    |> APNS.Request.build_finch_request()
    |> Finch.request(@finch)
    |> case do
      {:ok, %Finch.Response{status: 200}} -> :ok
      {:ok, %Finch.Response{} = error_response} -> {:error, error_response}
      {:error, _reason} = error -> error
    end
  end
end
