defmodule SinceWeb.MobileAuthControllerTest do
  use SinceWeb.ConnCase, async: true

  @token "eyJraWQiOiJZdXlYb1kiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwiYXVkIjoiY29tLmV4YW1wbGUuYXBwbGUtc2FtcGxlY29kZS5qdWljZVA4NVBZTEQ4VTIiLCJleHAiOjE2Mjc1ODc3MTgsImlhdCI6MTYyNzUwMTMxOCwic3ViIjoiMDAwMzU4LjE0NTNlMmQ0N2FmNTQwOWI5Y2YyMWFjN2EzYWI4NDVhLjE5NDEiLCJjX2hhc2giOiJBTkdfT2dxTzIxLVRPX0dXMi1CVW1nIiwiZW1haWwiOiJtbjVibWYyeXJzQHByaXZhdGVyZWxheS5hcHBsZWlkLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjoidHJ1ZSIsImlzX3ByaXZhdGVfZW1haWwiOiJ0cnVlIiwiYXV0aF90aW1lIjoxNjI3NTAxMzE4LCJub25jZV9zdXBwb3J0ZWQiOnRydWUsInJlYWxfdXNlcl9zdGF0dXMiOjJ9.dOztOl7SE54xjoDcun7uSnXxnrmL4-C5v1l3fbbEOnnYo_3DN3CWSfI-NqmvHM-yzp-b2nc66CfEnoSxUPHa-U5MRSYuQbLNnfhY0NTOZ8VvYby8gUrAvpfobfZ4zKou-15dvZPdnRAwn56Cq6eZ0LQAtcHkuTd9oLFjGtz27j3t8WuRd1VLZb6eZmB8prW7c7E9ztU61vQE9TJkdMYJ2LCaUCm_T1Z8GTu-CqTbXTlNKtzzbw7iH0IjRTZrn0jNsHRcMYueCwgDdYr9qS-husM-9g5X_RRU7VXrj6miCzsigil0aEVMqp-LqU0KNaVmlatWKoYSKPv1VTMZAcdjow"

  test "success: can register with valid token", %{conn: conn} do
    conn =
      post(conn, "/api/mobile/auth/verify-apple", %{
        "token" => Base.encode64(@token)
      })

    assert %{"user" => %{"email" => email, "id" => id}} = json_response(conn, 200)
    assert email == "mn5bmf2yrs@privaterelay.appleid.com"

    user = Repo.get!(Since.Accounts.User, id)
    assert user.email == email
    assert user.apple_id == "000358.1453e2d47af5409b9cf21ac7a3ab845a.1941"
  end

  test "failure: invalid token is refused", %{conn: conn} do
    conn =
      post(conn, "/api/mobile/auth/verify-apple", %{
        "token" => Base.encode64(replace_email_in_token(@token, "new@email.com"))
      })

    assert conn.status == 400
    assert conn.resp_body == ""
  end

  test "success: email is updated with most recent email form token", %{conn: conn} do
    apple_id = "000358.1453e2d47af5409b9cf21ac7a3ab845a.1941"
    insert(:user, apple_id: apple_id, email: "old@email.com")

    conn =
      post(conn, "/api/mobile/auth/verify-apple", %{
        "token" => Base.encode64(@token)
      })

    assert %{"user" => %{"email" => email}} = json_response(conn, 200)
    assert email == "mn5bmf2yrs@privaterelay.appleid.com"

    user = Repo.get_by!(Since.Accounts.User, apple_id: apple_id)
    assert user.email == email
  end

  defp replace_email_in_token(token, new_email) do
    [header, body, signature] = String.split(token, ".")

    new_body =
      body
      |> Base.decode64!()
      |> :json.decode()
      |> Map.put("email", new_email)
      |> :json.encode()
      |> Base.encode64()

    [header, new_body, signature] |> Enum.join(".")
  end
end
