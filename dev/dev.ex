defmodule Dev do
  # TODO
  # TO BE USED ONCE (THEN DELETED)
  def count_likes() do
    import Ecto.Query

    T.Feeds.FeedProfile
    |> T.Repo.update_all(set: [times_liked: 0])

    all_likes = T.Matches.Like |> T.Repo.all()

    for like <- all_likes do
      user_id = like.user_id

      T.Feeds.FeedProfile
      |> where(user_id: ^user_id)
      |> T.Repo.update_all(inc: [times_liked: 1])
    end
  end
end
