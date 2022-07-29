defmodule T.Feeds.FeedLimitResetJob do
  @moduledoc "Resets feed limit when the time comes"
  use Oban.Worker
  alias T.Feeds

  @impl true
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    if feed_limit = Feeds.fetch_feed_limit(user_id) do
      Feeds.local_reset_feed_limit(feed_limit)
    else
      :discard
    end
  end
end
