defmodule APNS do
  @moduledoc "Finch-based APNs client."
  require Logger

  @type env :: :dev | :prod
  @type notification :: %{payload: map, device_id: String.t(), topic: String.t(), env: env}
  @type response :: :ok | {:error, error_reason | Exception.t()}

  @doc "Builds a notification that can be sent to APNs"
  @spec build_notification(String.t(), String.t(), map, env) :: notification
  def build_notification(device_id, topic, payload, env) do
    %{device_id: device_id, topic: topic, payload: payload, env: env}
  end

  @spec url(env, String.t()) :: String.t()
  defp url(:dev, device_id), do: "https://api.development.push.apple.com/3/device/" <> device_id
  defp url(:prod, device_id), do: "https://api.push.apple.com/3/device/" <> device_id

  @doc "Pushes a notification to APNs"
  @spec push(notification, Finch.name()) :: response
  def push(notification, finch_name) do
    notification
    |> build_request()
    |> Finch.request(finch_name)
    |> case do
      {:ok, %Finch.Response{status: 200}} ->
        :ok

      {:ok, %Finch.Response{body: body}} ->
        {:error, body |> Jason.decode!() |> error_reason()}

      # in prod env (api.push.apple.com):
      # after connecting and before receiving response to the first request (stream)
      # mint thinks conn.server.max_concurrent_streams is 1 and makes other concurrent requests fail.
      # after receiving frame from the first stream that sets conn.servir.max_concurrent_streams = 1000
      # this error doesn't happen again (unless more than 1000 concurrent requests are sent)
      # https://gist.github.com/ruslandoga/8332cc8a2cf260c4c3a6d23386c8a06a

      # in sandbox env (api.development.push.apple.com):
      # conn.server.max_concurrent_streams = 1 always, so this error would happen whenever
      # more than 1 concurrent request is sent

      {:error, %Mint.HTTPError{module: Mint.HTTP2, reason: :too_many_concurrent_requests}} ->
        Logger.warn("apns too_many_concurrent_requests for #{inspect(notification)}")
        # the current workaround is an optimistic retry with a small delay of up to a second
        # hoping that at some point the queue of concurrent requests would clear
        :timer.sleep(round(:rand.uniform() * 1000))
        push(notification, finch_name)

      {:error, _reason} = error ->
        error
    end
  end

  @spec build_request(notification) :: Finch.Request.t()
  defp build_request(%{topic: topic, env: env} = notification) do
    token = APNS.Token.current_token(topic, env)
    build_request(notification, token)
  end

  @spec build_request(notification, String.t()) :: Finch.Request.t()
  defp build_request(notification, token) do
    %{
      payload: payload,
      device_id: device_id,
      env: env,
      topic: topic
    } = notification

    headers = [
      {"authorization", "bearer " <> token},
      {"apns-topic", topic},
      {"apns-push-type", "alert"}
    ]

    url = url(env, device_id)
    body = Jason.encode_to_iodata!(payload)
    Finch.build(:post, url, headers, body)
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
