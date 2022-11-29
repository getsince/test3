defmodule AppStore do
  @moduledoc "Finch-based App Store Server client."
  require Logger

  @type env :: :dev | :prod
  @type notification :: %{env: env}
  @type response :: :ok | {:error, error_reason | Exception.t()}

  @spec url(env) :: String.t()
  defp url(:dev),
    do: "https://api.storekit-sandbox.itunes.apple.com/inApps/v1/notifications/test/"

  defp url(:prod), do: "https://api.storekit.itunes.apple.com/inApps/v1/notifications/test/"

  @doc "Pushes a test notification to App Store"
  @spec push(notification, Finch.name()) :: response
  def push(notification, finch_name) do
    notification
    |> build_request()
    |> Finch.request(finch_name)
    |> case do
      {:ok, %Finch.Response{status: 200} = response} ->
        Logger.warn(response)
        :ok

      # {:ok, %Finch.Response{body: body}} ->
      #   {:error, body |> Jason.decode!() |> error_reason()}

      {:error, _reason} = error ->
        Logger.warn(error)
        error
    end
  end

  @spec build_request(notification) :: Finch.Request.t()
  defp build_request(notification) do
    token = AppStore.Token.current_token()
    build_request(notification, token)
  end

  @spec build_request(notification, String.t()) :: Finch.Request.t()
  defp build_request(notification, token) do
    %{env: env} = notification

    url = url(env)

    headers = [
      {"authorization", "bearer " <> token}
    ]

    request = Finch.build(:post, url, headers)
    Logger.warn(request)
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
