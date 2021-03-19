defmodule T.Bot do
  @moduledoc "TG bot for admins"

  def token do
    Application.fetch_env!(:nadia, :token)
  end

  def room_id do
    Application.fetch_env!(:nadia, :room_id)
  end

  def set_webhook do
    Nadia.set_webhook(url: TWeb.Router.Helpers.bot_url(TWeb.Endpoint, :webhook, token()))
  end

  def post_new_user(phone_number) do
    Nadia.send_message(room_id(), "new user #{phone_number}")
  end

  def post_user_onboarded(phone_number) do
    Nadia.send_message(room_id(), "user onboarded #{phone_number}")
  end

  def handle(params) do
    IO.inspect(params)
  end
end
