defmodule TWeb.CallView do
  use TWeb, :view
  alias T.Calls.Call

  def render("call.json", %{call: call}) do
    %Call{id: call_id, inserted_at: inserted_at, accepted_at: accepted_at, ended_at: ended_at} =
      call

    %{"id" => call_id, "started_at" => DateTime.from_naive!(inserted_at, "Etc/UTC")}
    |> maybe_put_date("accepted_at", accepted_at)
    |> maybe_put_date("ended_at", ended_at)
  end

  defp maybe_put_date(map, _key, nil), do: map
  defp maybe_put_date(map, key, %DateTime{} = date), do: Map.put(map, key, date)
end
