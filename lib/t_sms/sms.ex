defmodule T.SMS do
  alias ExAws.SNS

  def send_sms(phone_number, message) do
    message_attributes = [
      %{name: "AWS.SNS.SMS.SMSType", data_type: :string, value: {:string, "Transactional"}}
    ]

    publish_opts = [
      message_attributes: message_attributes,
      phone_number: phone_number
    ]

    message
    |> SNS.publish(publish_opts)
    |> ExAws.request()
  end
end
