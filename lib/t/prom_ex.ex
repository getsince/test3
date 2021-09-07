# defmodule T.PromEx do
#   @moduledoc false
#   use PromEx, otp_app: :t
#   alias PromEx.Plugins

#   @impl true
#   def plugins do
#     [
#       # PromEx built in plugins
#       {Plugins.Application,
#        git_sha_mfa: {T.Release, :git_sha, []}, git_author_mfa: {T.Release, :git_author, []}},
#       Plugins.Beam,
#       {Plugins.Phoenix, router: TWeb.Router},
#       Plugins.Ecto,
#       Plugins.Oban,
#       Plugins.PhoenixLiveView

#       # Add your own PromEx metrics plugins
#       # T.Users.PromExPlugin
#     ]
#   end

#   @impl true
#   def dashboard_assigns do
#     [datasource_id: "prometheus"]
#   end

#   @impl true
#   def dashboards do
#     [
#       # PromEx built in Grafana dashboards
#       {:prom_ex, "application.json"},
#       {:prom_ex, "beam.json"},
#       {:prom_ex, "phoenix.json"},
#       {:prom_ex, "ecto.json"},
#       {:prom_ex, "oban.json"},
#       {:prom_ex, "phoenix_live_view.json"}

#       # Add your dashboard definitions here with the format: {:otp_app, "path_in_priv"}
#       # {:t, "/grafana_dashboards/user_metrics.json"}
#     ]
#   end
# end
