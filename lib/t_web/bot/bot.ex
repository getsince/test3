defmodule TWeb.Bot do
  @moduledoc "Helpers to interact with Telegram bot."

  def webhook_url do
    TWeb.Router.Helpers.bot_url(TWeb.Endpoint, :webhook, T.Bot.token())
  end

  def set_webhook do
    T.Bot.set_webhook(webhook_url())
  end
end
