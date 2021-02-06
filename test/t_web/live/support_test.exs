defmodule TWeb.SupportLiveTest do
  use TWeb.LiveCase, async: true

  alias T.{Accounts, Support}
  alias T.Accounts.User

  setup do
    _admin = insert(:user, id: Support.admin_id(), phone_number: phone_number())
    {:ok, %User{} = user} = Accounts.register_user(%{phone_number: phone_number()})
    {:ok, user: Repo.preload(user, :profile), socket: connected_socket(user)}
  end

  @tag skip: true
  test "it works" do
    admin_conn = build_conn()
    assert nil = live(admin_conn, "/admin/support")
  end
end
