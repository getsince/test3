defmodule T.Factory do
  use ExMachina.Ecto, repo: T.Repo
  alias T.Accounts.User

  def user_factory do
    %User{phone_number: "+79999999999"}
  end

  def profile_factory do
    %User.Profile{user: build(:user)}
  end
end
