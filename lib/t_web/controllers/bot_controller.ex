defmodule TWeb.BotController do
  use TWeb, :controller
  alias T.Bot

  def webhook(conn, %{"token" => token} = params) do
    if Bot.token() == token do
      Bot.handle(params)
    end

    send_resp(conn, 200, [])
  end
end
