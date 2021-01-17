defmodule T.Accounts.UserTokenTest do
  use ExUnit.Case, async: true
  alias T.Accounts.UserToken

  describe "raw_token/1" do
    test "noop for raw token" do
      {token, _user_token} = UserToken.build_token(%{id: nil}, "mobile")
      assert token == UserToken.raw_token(token)
    end

    test "decodes decoded token" do
      {token, _user_token} = UserToken.build_token(%{id: nil}, "mobile")
      encoded_token = UserToken.encoded_token(token)
      assert token == UserToken.raw_token(encoded_token)
    end
  end

  describe "encoded_token/1" do
    test "it works" do
      {token, _user_token} = UserToken.build_token(%{id: nil}, "mobile")
      assert token == UserToken.raw_token(UserToken.encoded_token(token))
    end
  end
end
