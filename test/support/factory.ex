defmodule T.Factory do
  use ExMachina.Ecto, repo: T.Repo
  alias T.Accounts.User

  def user_factory do
    %User{phone_number: phone_number()}
  end

  def profile_factory do
    %User.Profile{user: build(:user)}
  end

  def phone_number do
    rand = to_string(:rand.uniform(9_999_999))
    "+7916" <> String.pad_leading(rand, 7, "0")
  end
end
