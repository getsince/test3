defmodule AppStore do
  @moduledoc "Finch-based App Store Server client."
  require Logger

  import Ecto.{Query, Changeset}

  alias T.{Repo, Bot, Accounts}
  alias AppStore.Notification

  @type env :: :dev | :prod
  @type notification :: Map.t()
  @type response :: :ok | :error

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

  @spec load_notification_history(String.t() | nil) :: response()
  def load_notification_history(pagination_token \\ nil) do
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

    push(payload, pagination_token, T.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        notifications =
          body
          |> Jason.decode!()
          |> Map.fetch!("notificationHistory")
          |> Enum.map(fn m -> m |> Map.fetch!("signedPayload") end)

        process_notifications(notifications)

        has_more = body |> Jason.decode!() |> Map.fetch!("hasMore")

        if has_more do
          pagination_token = body |> Jason.decode!() |> Map.fetch!("paginationToken")
          load_notification_history(pagination_token)
        else
          :ok
        end

      {:ok, response} ->
        Sentry.capture_message("failed to load notifications from App Store", extra: response)
        Logger.warn(response)
        :error

      {:error, reason} = error ->
        Sentry.capture_message("failed to load notifications from App Store", extra: reason)
        Logger.warn(error)
        :error
    end
  end

  @spec push(notification, String.t() | nil, Finch.name()) ::
          {:ok, Finch.Response.t()} | {:error, Exception.t()}
  defp push(notification, pagination_token, finch_name) do
    notification
    |> build_request(pagination_token)
    |> Finch.request(finch_name)
  end

  @spec build_request(notification, String.t() | nil) :: Finch.Request.t()
  defp build_request(notification, pagination_token) do
    {env, token} = AppStore.Token.current_env_and_token()
    build_request(notification, env, token, pagination_token)
  end

  @spec build_request(notification, env(), String.t(), String.t() | nil) :: Finch.Request.t()
  defp build_request(notification, env, token, pagination_token) do
    url =
      if pagination_token do
        url(env) <> "?paginationToken=#{pagination_token}"
      else
        url(env)
      end

    headers = [
      {"authorization", "Bearer " <> token},
      {"content-type", "application/json"}
    ]

    body = Jason.encode!(notification)
    request = Finch.build(:post, url, headers, body)
    request
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

        Accounts.set_premium(user_id, premium)

      _ ->
        :ok
    end
  end

  defp maybe_update_premium_status(%Notification{}), do: nil
end
