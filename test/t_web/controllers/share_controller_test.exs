defmodule TWeb.ShareControllerTest do
  use TWeb.ConnCase, async: true
  alias T.Share.{Email, Phone}

  describe "POST /api/share-email" do
    test "valid email is saved", %{conn: conn} do
      conn = post(conn, "/api/share-email", %{"email" => "some@email.com"})
      assert conn.status == 201
      assert Repo.get_by(Email, email: "some@email.com")
    end
  end

  describe "POST /api/share-phone" do
    test "valid email is saved", %{conn: conn} do
      conn = post(conn, "/api/share-phone", %{"phone" => "+79162834728"})
      assert conn.status == 201
      assert Repo.get_by(Phone, phone_number: "+79162834728")
    end
  end
end
