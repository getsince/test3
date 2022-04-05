defmodule Dev do
  def lb_register_target do
    AWS.ElasticLoadBalancingv2.register_targets(client(), "")
  end
end
