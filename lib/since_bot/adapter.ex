defmodule Since.Bot.Adapter do
  @moduledoc false
  @callback set_webhook(url :: String.t()) :: any
  @callback send_message(chat_id :: integer, text :: String.t(), opts :: Keyword.t()) :: any
end
