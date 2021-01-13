defmodule TWeb.MatchView do
  use TWeb, :view
  alias T.Matches.Message

  def render("message.json", %{message: %Message{} = message}) do
    Map.take(message, [:id, :author_id, :timestamp, :kind, :data])
  end
end
