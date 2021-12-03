defmodule TWeb.MatchView do
  use TWeb, :view
  alias TWeb.FeedView
  alias T.Matches.{Timeslot, MatchContact}

  def render("match.json", %{id: match_id, contact: %MatchContact{} = contact} = assigns) do
    case expiration_date(match_id) do
      nil ->
        %{
          "id" => match_id,
          "profile" => render(FeedView, "feed_profile.json", assigns),
          "contact" => render_contact(contact)
        }

      some ->
        %{
          "id" => match_id,
          "profile" => render(FeedView, "feed_profile.json", assigns),
          "contact" => render_contact(contact),
          "expiration_date" => some
        }
    end
  end

  def render("match.json", %{id: match_id, timeslot: %Timeslot{} = timeslot} = assigns) do
    case expiration_date(match_id) do
      nil ->
        %{
          "id" => match_id,
          "profile" => render(FeedView, "feed_profile.json", assigns),
          "timeslot" => render_timeslot(timeslot)
        }

      some ->
        %{
          "id" => match_id,
          "profile" => render(FeedView, "feed_profile.json", assigns),
          "timeslot" => render_timeslot(timeslot),
          "expiration_date" => some
        }
    end
  end

  def render("match.json", %{id: match_id} = assigns) do
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

  defp render_timeslot(%Timeslot{selected_slot: selected_slot})
       when not is_nil(selected_slot) do
    %{"selected_slot" => selected_slot}
  end

  defp render_timeslot(%Timeslot{picker_id: picker, slots: slots}) do
    %{"slots" => slots, "picker" => picker}
  end

  defp render_contact(%MatchContact{
         contact_type: contact_type,
         value: value,
         picker_id: picker,
         opened: opened
       }) do
    case opened do
      nil ->
        %{"contact_type" => contact_type, "value" => value, "picker" => picker}

      _some ->
        %{
          "contact_type" => contact_type,
          "value" => value,
          "picker" => picker,
          "opened" => opened
        }
    end
  end

  defp expiration_date(match_id) do
    T.Matches.expiration_date(match_id)
  end
end
