# defmodule T.Feed do
#   import Ecto.Query
#   alias T.Repo
#   alias T.Accounts.User

#   def subscribe_to_matched do
#     Phoenix.PubSub.subscribe(T.PubSub, to_string(__MODULE__))
#   end

#   # tables: profiles, possibly matches, seen

#   # TODO precompute feeds?
#   # TODO optimise query
#   def get_feed(%User.Profile{} = profile) do
#     most_liked = User.Profile
#     # all seen
#     |> with_cte()
#     |> where(gender: ^opposite_gender(profile))
#     |> where(matched?: false)
#     |> where([p], p.profile_id not in "seen")
#     |> order_by([p], p.times_liked)
#     |> limit(5)
#     |> Repo.all()

#     interests_overlap = User.Profile
#     # all seen
#     |> with_cte()
#     |> where(gender: ^opposite_gender(profile))
#     |> where(matched?: false)
#     |> where([p], p.profile_id not in "seen")
#     |> order_by([p], p.interests_overlap)
#     |> limit(5)
#     |> Repo.all()

#     User.Profile
#     # all seen
#     |> with_cte()
#     |> where(gender: ^opposite_gender(profile))
#     |> where(matched?: false)
#     |> where([p], p.profile_id not in "seen")
#     |> order_by([p], [p.times_liked, p.interests_overlap, p.last_time_active])
#   end

#   defp opposite_gender(%User.Profile{gender: "F"}), do: "M"
#   defp opposite_gender(%User.Profile{gender: "M"}), do: "F"
# end
