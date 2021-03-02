defmodule TWeb.YoController do
  use TWeb, :controller

  def ack_ios_yo(conn, %{"ack_id" => ack_id}) do
    T.Matches.ack_yo(ack_id)
    send_resp(conn, :ok, [])
  end
end
