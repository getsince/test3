defmodule Dev do
  def lb_register_target do
    AWS.ElasticLoadBalancingv2.register_targets(client(), "")
  end

  import Ecto.Query

  def rand_profiles(user_id, gender, feed_filter) do
    feed_profiles_q(user_id, gender, feed_filter.genders)
    |> maybe_apply_age_filters(feed_filter)
    |> maybe_apply_distance_filter(location, feed_filter.distance)
    |> select([p], %{p | distance: distance_km(^location, p.location)})
    |> order_by([fragment("random()"), fragment("location <-> ?::geometry", ^location)])
    |> limit(16)
    |> Repo.all()
  end
end
