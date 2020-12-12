defmodule T.Share do
  alias T.Repo
  alias __MODULE__.{Email, Phone}

  import Ecto.Changeset

  def save_email(email) do
    %Email{}
    |> cast(%{email: email}, [:email])
    |> validate_required([:email])
    # |> validate_format()
    |> Repo.insert()
  end

  def save_phone(phone) do
    %Phone{}
    |> cast(%{phone_number: phone}, [:phone_number])
    |> validate_required([:phone_number])
    # |> validate_format()
    |> Repo.insert()
  end
end
