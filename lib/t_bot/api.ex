defmodule T.Bot.API do
  @moduledoc false
  @behaviour T.Bot.Adapter

  @impl true
  def set_webhook(url) do
    request("setWebhook", %{"url" => url})
  end

  @impl true
  def send_message(chat_id, text) do
    request("sendMessage", %{"chat_id" => chat_id, "text" => text})
  end

  defp request(method, body) do
    req = Finch.build(method, build_url(method), [], Jason.encode_to_iodata!(body))
    Finch.request(req, T.Finch, receive_timeout: 20_000)
  end

  defp build_url(method) do
    "https://api.telegram.org/bot" <> T.Bot.token() <> "/" <> method
  end
end
