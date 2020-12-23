defmodule T.Share.ReferralCode do
  use Ecto.Schema

  @primary_key false
  schema "referral_codes" do
    field :code, :string, primary_key: true
    field :meta, :map
    timestamps(updated_at: false)
  end
end
