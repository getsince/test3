defmodule T.PushNotifications.APNS.Pigeon do
  @moduledoc false
  @behaviour T.PushNotifications.APNS.Adapter
  alias Pigeon.APNS
  alias Pigeon.APNS.Notification

  defguardp is_valid_env(env) when env in [:dev, :prod]

  @impl true
  @spec push(n, :dev | :prod) :: n when n: Notification.t() | [Notification.t()]
  def push(notifications, env) when is_valid_env(env) when is_list(notifications) do
    notifications |> APNS.push(to: env) |> Enum.map(&maybe_warned/1)
  end

  def push(%Notification{} = notification, env) when is_valid_env(env) do
    notification |> APNS.push(to: env) |> maybe_warned()
  end

  defp maybe_warned(%Notification{response: response} = notification) do
    unless response == :success do
      # Logger.warn("failed to send apns notification reason=#{response}: #{inspect(n)}")
      Sentry.capture_message(
        "failed to send apns notification reason=#{response}: #{inspect(notification)}"
      )
    end

    notification
  end
end
