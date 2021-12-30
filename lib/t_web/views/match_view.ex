defmodule TWeb.MatchView do
  use TWeb, :view
  alias TWeb.FeedView
  alias T.Matches.{Timeslot, MatchContact}
  alias T.Calls
  alias T.Calls.Voicemail

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

  defp maybe_put_interaction(match, [%Voicemail{} | _rest] = voicemail) do
    Map.put(match, "voicemail", render_voicemail(voicemail))
  end

  defp maybe_put_interaction(match, nil) do
    match
  end

  defp render_timeslot(%Timeslot{selected_slot: selected_slot})
       when not is_nil(selected_slot) do
    %{"selected_slot" => selected_slot}
  end

  defp render_timeslot(%Timeslot{picker_id: picker, slots: slots}) do
    %{"slots" => slots, "picker" => picker}
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

  defp render_voicemail(voicemail) do
    Enum.map(voicemail, fn %Voicemail{id: id, inserted_at: inserted_at, s3_key: s3_key} ->
      %{
        id: id,
        inserted_at: DateTime.from_naive!(inserted_at, "Etc/UTC"),
        s3_key: s3_key,
        url: Calls.voicemail_url(s3_key)
      }
    end)
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)
end
