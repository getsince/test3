defmodule SinceWeb.Bot do
  @moduledoc "Helpers to interact with Telegram bot."

  def webhook_url do
    SinceWeb.Router.Helpers.bot_url(SinceWeb.Endpoint, :webhook, Since.Bot.token())
  end

  def sesince_webhook do
    Since.Bot.sesince_webhook(webhook_url())
  end
end
