defmodule T.Accounts.UserTokenTest do
  use ExUnit.Case, async: true
  alias T.Accounts.{User, UserToken}

  @uuid "0000017b-88c0-1dd1-1e00-8a0e24450000"

  describe "raw_token/1" do
    test "noop for raw token" do
      {token, _user_token} = UserToken.build_token(%User{id: @uuid}, "mobile")
      assert token == UserToken.raw_token(token)
    end

    test "decodes decoded token" do
      {token, _user_token} = UserToken.build_token(%User{id: @uuid}, "mobile")
      encoded_token = UserToken.encoded_token(token)
      assert token == UserToken.raw_token(encoded_token)
    end
  end

  describe "encoded_token/1" do
    test "it works" do
      {token, _user_token} = UserToken.build_token(%User{id: @uuid}, "mobile")
      assert token == UserToken.raw_token(UserToken.encoded_token(token))
    end
  end
end
