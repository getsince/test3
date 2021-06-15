defmodule T.Bot.Adapter do
  @moduledoc false
  @callback set_webhook(url :: String.t()) :: any
  @callback send_message(chat_id :: integer, text :: String.t()) :: any
end
