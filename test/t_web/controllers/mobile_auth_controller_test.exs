defmodule TWeb.MobileAuthControllerTest do
  use TWeb.ConnCase, async: true

  test "registered success", %{conn: conn} do
    conn =
      post(conn, "/api/mobile/auth/verify-apple", %{
        "token" =>
          Base.encode64(
            "eyJraWQiOiJZdXlYb1kiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwiYXVkIjoiY29tLmV4YW1wbGUuYXBwbGUtc2FtcGxlY29kZS5qdWljZVA4NVBZTEQ4VTIiLCJleHAiOjE2Mjc1ODc3MTgsImlhdCI6MTYyNzUwMTMxOCwic3ViIjoiMDAwMzU4LjE0NTNlMmQ0N2FmNTQwOWI5Y2YyMWFjN2EzYWI4NDVhLjE5NDEiLCJjX2hhc2giOiJBTkdfT2dxTzIxLVRPX0dXMi1CVW1nIiwiZW1haWwiOiJtbjVibWYyeXJzQHByaXZhdGVyZWxheS5hcHBsZWlkLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjoidHJ1ZSIsImlzX3ByaXZhdGVfZW1haWwiOiJ0cnVlIiwiYXV0aF90aW1lIjoxNjI3NTAxMzE4LCJub25jZV9zdXBwb3J0ZWQiOnRydWUsInJlYWxfdXNlcl9zdGF0dXMiOjJ9.dOztOl7SE54xjoDcun7uSnXxnrmL4-C5v1l3fbbEOnnYo_3DN3CWSfI-NqmvHM-yzp-b2nc66CfEnoSxUPHa-U5MRSYuQbLNnfhY0NTOZ8VvYby8gUrAvpfobfZ4zKou-15dvZPdnRAwn56Cq6eZ0LQAtcHkuTd9oLFjGtz27j3t8WuRd1VLZb6eZmB8prW7c7E9ztU61vQE9TJkdMYJ2LCaUCm_T1Z8GTu-CqTbXTlNKtzzbw7iH0IjRTZrn0jNsHRcMYueCwgDdYr9qS-husM-9g5X_RRU7VXrj6miCzsigil0aEVMqp-LqU0KNaVmlatWKoYSKPv1VTMZAcdjow"
          )
      })

    assert json_response(conn, 200)["user"]["email"] == "mn5bmf2yrs@privaterelay.appleid.com"
  end
end
