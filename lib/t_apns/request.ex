defmodule T.APNS.Request do
  defstruct [:payload, :device_id, :topic, :env, push_type: "alert"]

  @type t :: %__MODULE__{
          payload: map,
          device_id: String.t(),
          topic: String.t(),
          push_type: String.t(),
          env: :dev | :prod
        }

  @spec new(String.t(), String.t(), map, :dev | :prod) :: t
  def new(device_id, topic, payload, env) do
    %__MODULE__{device_id: device_id, topic: topic, payload: payload, env: env}
  end

  def url(:dev, device_id), do: "https://api.development.push.apple.com/3/device/" <> device_id
  def url(:prod, device_id), do: "https://api.push.apple.com/3/device/" <> device_id

  def build_finch_request(
        %__MODULE__{
          payload: payload,
          device_id: device_id,
          topic: topic,
          push_type: push_type,
          env: env
        },
        token
      ) do
    headers = [
      {"apns-topic", topic},
      {"apns-push-type", push_type},
      {"authorization", "bearer " <> token}
    ]

    body = Jason.encode_to_iodata!(payload)
    Finch.build(:post, url(env, device_id), headers, body)
  end
end
