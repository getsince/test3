defmodule AppStore do
  @moduledoc "Finch-based App Store Server client."
  require Logger

  import Ecto.{Query, Changeset}

  alias T.{Repo, Bot}
  alias T.Accounts.Profile
  alias AppStore.Notification

  @type env :: :dev | :prod
  @type notification :: Map.t()
  @type response :: :ok | {:error, error_reason | Exception.t()}

  @significant_notification_types [
    "DID_FAIL_TO_RENEW",
    "DID_RENEW",
    "EXPIRED",
    "GRACE_PERIOD_EXPIRED",
    "REVOKE",
    "SUBSCRIBED"
  ]

  defmodule Notificator do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def init(_opts) do
      AppStore.load_notification_history()
      :ignore
    end
  end

  @spec url(env) :: String.t()
  defp url(:dev),
    do: "https://api.storekit-sandbox.itunes.apple.com/inApps/v1/notifications/history/"

  defp url(:prod), do: "https://api.storekit.itunes.apple.com/inApps/v1/notifications/test/"

  @spec load_notification_history() :: response()
  def load_notification_history() do
    start_date =
      Notification
      |> order_by([n], desc: n.signed_date)
      |> limit(1)
      |> select([n], n.signed_date)
      |> Repo.all()
      |> case do
        [] -> :os.system_time(:millisecond) - 1000 * 60 * 60 * 24 * 30
        [signed_date] -> signed_date |> DateTime.to_unix(:millisecond)
      end

    payload = %{"startDate" => start_date, "endDate" => :os.system_time(:millisecond)}

    push(payload, T.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        notifications =
          body
          |> Jason.decode!()
          |> Map.fetch!("notificationHistory")
          |> Enum.map(fn m -> m |> Map.fetch!("signedPayload") end)

        process_notifications(notifications)

        # TODO
        has_more =
          body
          |> Jason.decode!()
          |> Map.fetch!("hasMore")

        IO.inspect("hasMore #{has_more}")

        :ok

      {:ok, %Finch.Response{body: body}} ->
        {:error, body |> Jason.decode!() |> error_reason()}

      {:error, _reason} = error ->
        Logger.warn(error)
        error
    end
  end

  defp process_notifications(notifications),
    do: Enum.each(notifications, fn n -> process_notification(n) end)

  def process_notification(notification) do
    payload = decode(notification)
    renewal_info = decode(payload["data"]["signedRenewalInfo"])
    transaction_info = decode(payload["data"]["signedTransactionInfo"])

    # TODO primary_rpc
    notification_changeset(%{
      notification_uuid: payload["notificationUUID"],
      signed_date: datetime_from_unix(payload["signedDate"]),
      user_id: transaction_info["appAccountToken"],
      notification_type: payload["notificationType"],
      subtype: payload["subtype"],
      purchase_date: datetime_from_unix(transaction_info["purchaseDate"]),
      expires_date: datetime_from_unix(transaction_info["expiresDate"]),
      transaction_id: transaction_info["transactionId"],
      original_transaction_id: transaction_info["originalTransactionId"],
      original_purchase_date: datetime_from_unix(transaction_info["originalPurchaseDate"]),
      revocation_date: datetime_from_unix(transaction_info["revocationDate"]),
      revocation_reason: transaction_info["revocationReason"],
      data:
        payload["data"]
        |> Map.drop(["signedRenewalInfo", "signedTransactionInfo"])
        |> Map.merge(%{"renewal_info" => renewal_info, "transaction_info" => transaction_info})
    })
    |> Repo.insert()
    |> case do
      {:ok,
       %Notification{notification_type: type, subtype: subtype, user_id: user_id} = notification} ->
        m = "App Store notication type #{type} #{subtype} for user #{user_id}"
        Logger.warn(m)
        Bot.async_post_message(m)
        maybe_update_premium_status(notification)

      {:error, _changeset} ->
        :ok
    end
  end

  defp decode(nil), do: nil

  defp decode(signedPayload) do
    [_header, payload, _signature] = String.split(signedPayload, ".")
    decoded_payload = payload |> Base.url_decode64!(padding: false) |> Jason.decode!()
    decoded_payload
  end

  defp datetime_from_unix(nil), do: nil
  defp datetime_from_unix(unix), do: unix |> DateTime.from_unix!(:millisecond)

  defp notification_changeset(attrs) do
    %Notification{}
    |> cast(attrs, [
      :notification_uuid,
      :signed_date,
      :user_id,
      :notification_type,
      :subtype,
      :purchase_date,
      :expires_date,
      :transaction_id,
      :original_transaction_id,
      :original_purchase_date,
      :revocation_date,
      :revocation_reason,
      :data
    ])
    |> validate_required([
      :notification_uuid,
      :signed_date,
      :notification_type,
      :transaction_id,
      :data
    ])
    |> unique_constraint(:notification_uuid, name: :app_store_notifications_pkey)
  end

  defp maybe_update_premium_status(%Notification{user_id: nil}), do: nil

  defp maybe_update_premium_status(%Notification{
         notification_type: type,
         user_id: user_id
       })
       when type in @significant_notification_types do
    Notification
    |> where(user_id: ^user_id)
    |> where([n], n.notification_type in @significant_notification_types)
    |> order_by([n], desc: n.signed_date)
    |> limit(1)
    |> select([n], {n.notification_type, n.subtype})
    |> Repo.all()
    |> case do
      [{notification_type, subtype}] ->
        premium =
          case notification_type do
            "DID_FAIL_TO_RENEW" ->
              case subtype do
                "GRACE_PERIOD" -> true
                _ -> false
              end

            "DID_RENEW" ->
              true

            "EXPIRED" ->
              false

            "GRACE_PERIOD_EXPIRED" ->
              false

            "REVOKE" ->
              false

            "SUBSCRIBED" ->
              true
          end

        m = "setting premium for user #{user_id} to #{premium}"
        Logger.warn(m)
        Bot.async_post_message(m)

        %Profile{user_id: user_id} |> Ecto.Changeset.change(premium: premium) |> Repo.update!()

      _ ->
        :ok
    end
  end

  defp maybe_update_premium_status(%Notification{}), do: nil

  @spec push(notification, Finch.name()) :: {:ok, Finch.Response.t()} | {:error, Exception.t()}
  defp push(notification, finch_name) do
    notification
    |> build_request()
    |> Finch.request(finch_name)
  end

  @spec build_request(notification) :: Finch.Request.t()
  defp build_request(notification) do
    {env, token} = AppStore.Token.current_env_and_token()
    build_request(notification, env, token)
  end

  @spec build_request(notification, env(), String.t()) :: Finch.Request.t()
  defp build_request(notification, env, token) do
    url = url(env)

    headers = [
      {"authorization", "Bearer " <> token},
      {"content-type", "application/json"}
    ]

    body = Jason.encode!(notification)
    request = Finch.build(:post, url, headers, body)
    request
  end

  defp error_reason(%{"reason" => reason}) do
    error_reason(reason)
  end

  error_mappings = %{
    "BadCollapseId" => :bad_collapse_id,
    "BadDeviceToken" => :bad_device_token,
    "BadExpirationDate" => :bad_expiration_date,
    "BadMessageId" => :bad_message_id,
    "BadPriority" => :bad_priority,
    "BadTopic" => :bad_topic,
    "DeviceTokenNotForTopic" => :device_token_not_for_topic,
    "DuplicateHeaders" => :duplicate_headers,
    "IdleTimeout" => :idle_timeout,
    "InvalidPushType" => :invalid_push_type,
    "MissingDeviceToken" => :missing_device_token,
    "MissingTopic" => :missing_topic,
    "PayloadEmpty" => :payload_empty,
    "TopicDisallowed" => :topic_disallowed,
    "BadCertificate" => :bad_certificate,
    "BadCertificateEnvironment" => :bad_certificate_environment,
    "ExpiredProviderToken" => :expired_provider_token,
    "Forbidden" => :forbidden,
    "InvalidProviderToken" => :invalid_provider_token,
    "MissingProviderToken" => :missing_provider_token,
    "BadPath" => :bad_path,
    "MethodNotAllowed" => :method_not_allowed,
    "Unregistered" => :unregistered,
    "PayloadTooLarge" => :payload_too_large,
    "TooManyProviderTokenUpdates" => :too_many_provider_token_updates,
    "TooManyRequests" => :too_many_requests,
    "InternalServerError" => :internal_server_error,
    "ServiceUnavailable" => :service_unavailable,
    "Shutdown" => :shutdown
  }

  error_reasons = Enum.map(error_mappings, fn {_, v} -> v end)
  error_reason_union = Enum.reduce(error_reasons, &{:|, [], [&1, &2]})
  @type error_reason :: unquote(error_reason_union)

  for {k, v} <- error_mappings do
    defp error_reason(unquote(k)), do: unquote(v)
  end
end
