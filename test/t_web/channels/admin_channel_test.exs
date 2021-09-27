defmodule TWeb.AdminChannelTest do
  use TWeb.ChannelCase

  test "non-admin can't join" do
    not_admin = onboarded_user()
    socket = connected_socket(not_admin)
    assert {:error, %{"error" => "forbidden"}} = join(socket, "admin")
  end

  test "admin can join" do
    admin = insert(:user, id: "36a0a181-db31-400a-8397-db7f560c152e")
    socket = connected_socket(admin)
    assert {:ok, reply, _socket} = join(socket, "admin")
    assert reply == %{"profiles" => []}
  end
end
