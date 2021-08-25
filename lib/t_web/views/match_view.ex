defmodule TWeb.MatchView do
  use TWeb, :view
  alias TWeb.FeedView
  alias T.Matches.Timeslot

  def render("match.json", %{id: match_id, timeslot: %Timeslot{} = timeslot} = assigns) do
    %{
      "id" => match_id,
      "profile" => render(FeedView, "feed_profile.json", assigns),
      "timeslot" => render_timeslot(timeslot)
    }
  end

  def render("match.json", %{id: match_id} = assigns) do
    %{
      "id" => match_id,
      "profile" => render(FeedView, "feed_profile.json", assigns)
    }
  end

  defp render_timeslot(%Timeslot{selected_slot: selected_slot})
       when not is_nil(selected_slot) do
    %{"selected_slot" => selected_slot}
  end

  defp render_timeslot(%Timeslot{picker_id: picker, slots: slots}) do
    %{"slots" => slots, "picker" => picker}
  end
end
