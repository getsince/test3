defmodule TWeb.Bot do
  @moduledoc "Helpers to interact with Telegram bot."

  use TWeb, :verified_routes

  def webhook_url do
    ~p"/api/bot/#{T.Bot.token()}"
  end

  def set_webhook do
    T.Bot.set_webhook(webhook_url())
  end
end
