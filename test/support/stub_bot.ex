defmodule StubBot do
  @behaviour Since.Bot.Adapter

  @impl true
  def set_webhook(_url), do: :ok

  @impl true
  def send_message(_chat_id, _text, _opts), do: :ok
end
