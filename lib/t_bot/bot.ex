defmodule T.Bot do
  @moduledoc "TG bot for admins"
  @adapter Application.compile_env!(:t, [__MODULE__, :adapter])

  defp config(key), do: config()[key]

  defp config do
    Application.fetch_env!(:t, __MODULE__)
  end

  def token, do: config(:token)
  def room_id, do: config(:room_id)

  def set_webhook do
    @adapter.set_webhook(TWeb.Router.Helpers.bot_url(TWeb.Endpoint, :webhook, token()))
  end

  def post_new_user(phone_number) do
    @adapter.send_message(room_id(), "new user #{phone_number}")
  end

  def post_user_onboarded(phone_number) do
    @adapter.send_message(room_id(), "user onboarded #{phone_number}")
  end

  def handle(_params), do: :ok
end
