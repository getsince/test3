defmodule T.Accounts.SMSCode do
  use Ecto.Schema

  @primary_key false
  schema "sms_codes" do
    field :phone_number, :string, primary_key: true
    field :code, :string
    field :attempts, :integer
    timestamps(updated_at: false)
  end
end
