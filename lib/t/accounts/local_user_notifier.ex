defmodule T.Accounts.LocalUserNotifier do
  @behaviour T.Accounts.UserNotifier

  @impl true
  def deliver(phone_number, body) do
    require Logger
    Logger.debug("[T.Accounts.LocalUserNotifier] Phone number: #{phone_number}, Body: #{body}")
    {:ok, %{to: phone_number, body: body}}
  end
end
