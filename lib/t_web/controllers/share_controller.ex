defmodule TWeb.ShareController do
  use TWeb, :controller
  alias T.Share

  action_fallback TWeb.FallbackController

  def check_if_available(conn, %{"code" => code}) do
    # TODO rate limit
    is_available? = Share.code_available?(code)

    conn
    |> put_status(200)
    |> text(to_string(is_available?))
  end

  def save_code(conn, %{"code" => _code} = attrs) do
    # TODO rate limit
    attrs = Map.put(attrs, "meta", build_meta(conn, attrs))

    with {:ok, _code} <- Share.save_code(attrs) do
      send_resp(conn, 201, [])
    end
  end

  defp build_meta(conn, attrs) do
    (attrs["meta"] || %{})
    |> Map.put("ip", conn.remote_ip |> :inet.ntoa() |> to_string())
    |> Map.put("user-agent", conn |> get_req_header("user-agent") |> List.first())
    |> maybe_put("ref", attrs["ref"])
    |> maybe_put("click_id", attrs["click_id"])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  def email(conn, %{"email" => email}) do
    with {:ok, _email} <- Share.save_email(email) do
      send_resp(conn, 201, [])
    end
  end

  def phone(conn, %{"phone" => phone} = attrs) do
    attrs =
      attrs
      |> Map.put("phone_number", phone)
      |> Map.put("meta", build_meta(conn, attrs))

    maybe_postback(attrs)

    with {:ok, _phone} <- Share.save_phone(attrs) do
      send_resp(conn, 201, [])
    end
  end

  defp maybe_postback(%{"ref" => "startapp", "click_id" => click_id}) do
    Task.start(fn ->
      url = "http://www.startappinstalls.com/trackinstall/selfservice?d=&startapp=" <> click_id
      HTTPoison.get!(url)
    end)
  end

  defp maybe_postback(_other), do: nil
end
