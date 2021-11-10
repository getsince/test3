defmodule TWeb.MatchView do
  use TWeb, :view
  alias TWeb.FeedView
  alias T.Matches.Timeslot

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

  defp expiration_date(match_id) do
    T.Matches.expiration_date(match_id)
  end
end
