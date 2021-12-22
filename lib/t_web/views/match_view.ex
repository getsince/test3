defmodule TWeb.MatchView do
  use TWeb, :view
  alias TWeb.FeedView
  alias T.Matches.{Timeslot, MatchContact}

  def render(
        "match.json",
        %{id: match_id, audio_only: audio_only, contact: %MatchContact{} = contact} = assigns
      ) do
    case expiration_date(match_id) do
      nil ->
        %{
          "id" => match_id,
          "audio_only" => audio_only,
          "profile" => render(FeedView, "feed_profile.json", assigns),
          "contact" => render_contact(contact)
        }

      some ->
        %{
          "id" => match_id,
          "audio_only" => audio_only,
          "profile" => render(FeedView, "feed_profile.json", assigns),
          "contact" => render_contact(contact),
          "expiration_date" => some
        }
    end
  end

  def render(
        "match.json",
        %{id: match_id, audio_only: audio_only, timeslot: %Timeslot{} = timeslot} = assigns
      ) do
    case expiration_date(match_id) do
      nil ->
        %{
          "id" => match_id,
          "audio_only" => audio_only,
          "profile" => render(FeedView, "feed_profile.json", assigns),
          "timeslot" => render_timeslot(timeslot)
        }

      some ->
        %{
          "id" => match_id,
          "audio_only" => audio_only,
          "profile" => render(FeedView, "feed_profile.json", assigns),
          "timeslot" => render_timeslot(timeslot),
          "expiration_date" => some
        }
    end
  end

  def render("match.json", %{id: match_id, audio_only: nil} = assigns) do
    case expiration_date(match_id) do
      nil ->
        %{
          "id" => match_id,
          "profile" => render(FeedView, "feed_profile.json", assigns)
        }

      some ->
        %{
          "id" => match_id,
          "profile" => render(FeedView, "feed_profile.json", assigns),
          "expiration_date" => some
        }
    end
  end

  def render("match.json", %{id: match_id, audio_only: audio_only} = assigns) do
    case expiration_date(match_id) do
      nil ->
        %{
          "id" => match_id,
          "audio_only" => audio_only,
          "profile" => render(FeedView, "feed_profile.json", assigns)
        }

      some ->
        %{
          "id" => match_id,
          "audio_only" => audio_only,
          "profile" => render(FeedView, "feed_profile.json", assigns),
          "expiration_date" => some
        }
    end
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
         contact_type: contact_type,
         value: value,
         picker_id: picker,
         opened_contact_type: opened_contact_type
       }) do
    %{
      "contacts" => contacts,
      "contact_type" => contact_type,
      "value" => value,
      "picker" => picker,
      "opened_contact_type" => opened_contact_type
    }
  end

  defp expiration_date(match_id) do
    T.Matches.expiration_date(match_id)
  end
end
