defmodule StubBot do
  @behaviour T.Bot.Adapter

  @impl true
  def set_webhook(_url), do: :ok

  @impl true
  def send_message(_chat_id, _text), do: :ok
end
