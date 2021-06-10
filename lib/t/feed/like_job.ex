defmodule T.Feeds.LikeJob do
  use Oban.Worker, unique: [period: 60], queue: :likes

  @impl true
  def perform(%Oban.Job{args: args}) do
    %{"by_user_id" => by_user_id, "user_id" => user_id} = args
    T.Feeds.like_profile(by_user_id, user_id)
  end
end
