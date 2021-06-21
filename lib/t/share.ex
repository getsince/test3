defmodule T.Share do
  alias T.Repo
  alias __MODULE__.{Email, Phone, ReferralCode}
  import Ecto.{Query, Changeset}

  def save_email(email) do
    %Email{}
    |> cast(%{email: email}, [:email])
    |> validate_required([:email])
    # |> validate_format()
    |> Repo.insert()
  end

  def save_phone(attrs) do
    %Phone{}
    |> cast(attrs, [:phone_number, :meta])
    |> validate_required([:phone_number])
    # |> validate_format()
    |> Repo.insert()
  end

  def code_available?(code) do
    exists? =
      ReferralCode
      |> where(code: ^code)
      |> Repo.exists?()

    not exists?
  end

  def save_code(attrs) do
    %ReferralCode{}
    |> cast(attrs, [:code, :meta])
    |> validate_required([:code])
    |> validate_length(:code, mix: 3, max: 40)
    |> unique_constraint(:code)
    |> Repo.insert()
  end
end
