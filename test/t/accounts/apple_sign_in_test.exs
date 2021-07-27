defmodule T.Accounts.AppleSignInTest do
  use ExUnit.Case, async: true
  alias T.Accounts.AppleSignIn

  @keys [
    %{
      "alg" => "RS256",
      "e" => "AQAB",
      "kid" => "86D88Kf",
      "kty" => "RSA",
      "n" =>
        "iGaLqP6y-SJCCBq5Hv6pGDbG_SQ11MNjH7rWHcCFYz4hGwHC4lcSurTlV8u3avoVNM8jXevG1Iu1SY11qInqUvjJur--hghr1b56OPJu6H1iKulSxGjEIyDP6c5BdE1uwprYyr4IO9th8fOwCPygjLFrh44XEGbDIFeImwvBAGOhmMB2AD1n1KviyNsH0bEB7phQtiLk-ILjv1bORSRl8AK677-1T8isGfHKXGZ_ZGtStDe7Lu0Ihp8zoUt59kx2o9uWpROkzF56ypresiIl4WprClRCjz8x6cPZXU2qNWhu71TQvUFwvIvbkE1oYaJMb0jcOTmBRZA2QuYw-zHLwQ",
      "use" => "sig"
    },
    %{
      "alg" => "RS256",
      "e" => "AQAB",
      "kid" => "eXaunmL",
      "kty" => "RSA",
      "n" =>
        "4dGQ7bQK8LgILOdLsYzfZjkEAoQeVC_aqyc8GC6RX7dq_KvRAQAWPvkam8VQv4GK5T4ogklEKEvj5ISBamdDNq1n52TpxQwI2EqxSk7I9fKPKhRt4F8-2yETlYvye-2s6NeWJim0KBtOVrk0gWvEDgd6WOqJl_yt5WBISvILNyVg1qAAM8JeX6dRPosahRVDjA52G2X-Tip84wqwyRpUlq2ybzcLh3zyhCitBOebiRWDQfG26EH9lTlJhll-p_Dg8vAXxJLIJ4SNLcqgFeZe4OfHLgdzMvxXZJnPp_VgmkcpUdRotazKZumj6dBPcXI_XID4Z4Z3OM1KrZPJNdUhxw",
      "use" => "sig"
    },
    %{
      "alg" => "RS256",
      "e" => "AQAB",
      "kid" => "YuyXoY",
      "kty" => "RSA",
      "n" =>
        "1JiU4l3YCeT4o0gVmxGTEK1IXR-Ghdg5Bzka12tzmtdCxU00ChH66aV-4HRBjF1t95IsaeHeDFRgmF0lJbTDTqa6_VZo2hc0zTiUAsGLacN6slePvDcR1IMucQGtPP5tGhIbU-HKabsKOFdD4VQ5PCXifjpN9R-1qOR571BxCAl4u1kUUIePAAJcBcqGRFSI_I1j_jbN3gflK_8ZNmgnPrXA0kZXzj1I7ZHgekGbZoxmDrzYm2zmja1MsE5A_JX7itBYnlR41LOtvLRCNtw7K3EFlbfB6hkPL-Swk5XNGbWZdTROmaTNzJhV-lWT0gGm6V1qWAK2qOZoIDa_3Ud0Gw",
      "use" => "sig"
    }
  ]

  # TODO would token expire and test fail later? I guess I'll find out
  test "valid token" do
    token =
      "eyJraWQiOiJZdXlYb1kiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL2FwcGxlaWQuYXBwbGUuY29tIiwiYXVkIjoiY29tLmV4YW1wbGUuYXBwbGUtc2FtcGxlY29kZS5qdWljZVA4NVBZTEQ4VTIiLCJleHAiOjE2Mjc1ODc3MTgsImlhdCI6MTYyNzUwMTMxOCwic3ViIjoiMDAwMzU4LjE0NTNlMmQ0N2FmNTQwOWI5Y2YyMWFjN2EzYWI4NDVhLjE5NDEiLCJjX2hhc2giOiJBTkdfT2dxTzIxLVRPX0dXMi1CVW1nIiwiZW1haWwiOiJtbjVibWYyeXJzQHByaXZhdGVyZWxheS5hcHBsZWlkLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjoidHJ1ZSIsImlzX3ByaXZhdGVfZW1haWwiOiJ0cnVlIiwiYXV0aF90aW1lIjoxNjI3NTAxMzE4LCJub25jZV9zdXBwb3J0ZWQiOnRydWUsInJlYWxfdXNlcl9zdGF0dXMiOjJ9.dOztOl7SE54xjoDcun7uSnXxnrmL4-C5v1l3fbbEOnnYo_3DN3CWSfI-NqmvHM-yzp-b2nc66CfEnoSxUPHa-U5MRSYuQbLNnfhY0NTOZ8VvYby8gUrAvpfobfZ4zKou-15dvZPdnRAwn56Cq6eZ0LQAtcHkuTd9oLFjGtz27j3t8WuRd1VLZb6eZmB8prW7c7E9ztU61vQE9TJkdMYJ2LCaUCm_T1Z8GTu-CqTbXTlNKtzzbw7iH0IjRTZrn0jNsHRcMYueCwgDdYr9qS-husM-9g5X_RRU7VXrj6miCzsigil0aEVMqp-LqU0KNaVmlatWKoYSKPv1VTMZAcdjow"

    assert {:ok,
            %{
              id: "000358.1453e2d47af5409b9cf21ac7a3ab845a.1941",
              email: "mn5bmf2yrs@privaterelay.appleid.com",
              is_private_email: true
            }} = AppleSignIn.fields_from_token(token, @keys)
  end
end
