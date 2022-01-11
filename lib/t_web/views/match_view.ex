defmodule TWeb.MatchView do
  use TWeb, :view
  alias TWeb.FeedView
  alias T.Matches.{Timeslot, MatchContact}

  def render("match.json", %{id: id} = assigns) do
    %{"id" => id, "profile" => render(FeedView, "feed_profile.json", assigns)}
    |> maybe_put("audio_only", assigns[:audio_only])
    |> maybe_put("expiration_date", assigns[:expiration_date])
    |> maybe_put_interaction(assigns[:interaction])
  end

  defp maybe_put_interaction(match, %Timeslot{} = timeslot) do
    Map.put(match, "timeslot", render_timeslot(timeslot))
  end

  defp maybe_put_interaction(match, %MatchContact{} = contact) do
    Map.put(match, "contact", render_contact(contact))
  end

  defp maybe_put_interaction(match, nil) do
    match
  end

  defp render_timeslot(%Timeslot{
         selected_slot: nil,
         accepted_at: nil,
         picker_id: picker,
         slots: slots
       }) do
    %{"slots" => slots, "picker" => picker}
  end

  defp render_timeslot(%Timeslot{selected_slot: selected_slot, accepted_at: accepted_at}) do
    %{"selected_slot" => selected_slot, "accepted_at" => accepted_at}
  end

  defp render_contact(%MatchContact{
         contacts: contacts,
         picker_id: picker,
         opened_contact_type: opened_contact_type
       }) do
    %{
      "contacts" => contacts,
      "picker" => picker,
      "opened_contact_type" => opened_contact_type
    }
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)
end
