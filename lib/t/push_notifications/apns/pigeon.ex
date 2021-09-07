defmodule T.PushNotifications.APNS.Pigeon do
  @moduledoc false
  @behaviour T.PushNotifications.APNS.Adapter
  alias Pigeon.APNS
  alias Pigeon.APNS.Notification

  defguardp is_valid_env(env) when env in [:dev, :prod]

  @impl true
  @spec push(n, :dev | :prod) :: n when n: Notification.t() | [Notification.t()]
  def push(notifications, env) when is_valid_env(env) do
    notifications |> APNS.push(to: env) |> maybe_warned()
  end

  defp maybe_warned(notifications) when is_list(notifications) do
    Enum.map(notifications, &maybe_warned/1)
  end

  defp maybe_warned(%Notification{response: response} = notification) do
    unless response == :success do
      Sentry.capture_message(
        "failed to send apns notification reason=#{response}: #{inspect(notification)}"
      )
    end

    notification
  end
end
