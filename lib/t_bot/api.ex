defmodule T.Bot.API do
  @moduledoc false
  @behaviour T.Bot.Adapter

  @impl true
  def set_webhook(url) do
    request("setWebhook", %{"url" => url})
  end

  @impl true
  # https://core.telegram.org/bots/api#sendmessage
  def send_message(chat_id, text, opts) do
    payload = Enum.into(opts, %{"chat_id" => chat_id, "text" => text})
    request("sendMessage", payload)
  end

  @default_headers [{"content-type", "application/json"}]

  defp request(method, body) do
    req = Finch.build(:post, build_url(method), @default_headers, :json.encode(body))
    Finch.request(req, T.Finch, receive_timeout: 20_000)
  end

  defp build_url(method) do
    "https://api.telegram.org/bot" <> T.Bot.token() <> "/" <> method
  end
end
