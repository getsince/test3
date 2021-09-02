defmodule Dev do
  # alias T.PushNotifications.APNS

  # def attach do
  #   detach()

  #   :telemetry.attach_many(
  #     "test-handler",
  #     [[:phoenix, :endpoint, :stop], [:phoenix, :router_dispatch, :stop]],
  #     fn event, measurements, metadata, config ->
  #       IO.inspect(event: event, measurements: measurements, metadata: metadata, config: config)
  #     end,
  #     _config = nil
  #   )
  # end

  # def detach do
  #   :telemetry.detach("test-handler")
  # end

  # def send_notification(locale \\ "en") do
  #   device_id = System.get_env("MY_APNS_ID")

  #   n =
  #     Gettext.with_locale(locale, fn ->
  #       APNS.build_notification("timeslot_started", device_id, %{})
  #     end)

  #   APNS.push(n)
  # end
end

# 1
# active_sessions: ordered_set {id}
# profiles: set {session_id, gender, gender_preferences, user_id, name, story}

# defmodule FeedCache1 do
#   def init(_opts) do
#     :active_sessions = :ets.new(:active_sessions, [:named_table, :ordered_set])
#     :active_profiles = :ets.new(:active_profiles, [:named_table])
#   end

#   def more(after_id, gender, gender_preference, count \\ 10)

#   def more(after_id, gender, gender_preference, count) when count > 1 do
#     case :ets.next(:active_sessions, after_id) do
#       id when is_integer(id) ->
#         [{_id, mate_gender, mate_gender_preference, _user_id, _name, _story} = profile] =
#           :ets.lookup(:active_profiles, id)

#         if mate_gender in gender_preference and gender in mate_gender_preference do
#           [profile | more(id, gender, gender_preference, count - 1)]
#         else
#           more(id, gender, gender_preference, count)
#         end

#       :"$end_of_table" ->
#         []
#     end
#   end

#   def more(_after_id, _gender, _gender_preference, _count), do: []
# end

# 2
# or maybe active_sessions: ordered_set {session_id}
# filter: set {session_id, gender, gender_preferences, user_id}
# profiles: set {user_id, name, story}

# 3
# table per gender*gender_preference combination (9 tables)

# defmodule FeedCache3 do
#   def more(after_id, gender, gender_preferences, count \\ 10)

#   def more(after_ids, gender, gender_preferences, count) when count > 1 do
#     tables = tables(gender_preferences, gender)

#     more_continue(after_ids, tables, count, _acc = [])
#   end

#   defp more_continue([after_id | ids], [table | tables], count, acc) do
#     case :ets.next(table, after_id) do
#       id -> more_continue(ids, tables, count - 1, [id | acc])
#       :end -> more_continue(ids, tables, count, acc)
#     end
#   end

#   defp gender_preferences([p1, p2, p3], gender),
#     do: [table(p1, gender), table(p2, gender), table(p3, gender)]

#   defp gender_preferences([p1, p2], gender), do: [table(p1, gender), table(p2, gender)]
#   defp gender_preferences([p1], gender), do: [table(p1, gender)]
#   defp gender_preferences([], _gender), do: []

#   def more([after_id | rest_ids], gender, [gender_preference | rest_prefs], count)
#       when count > 1 do
#     case :ets.next(tab = table(gender, gender_preference), after_id) do
#       id when is_integer(id) ->
#         [{tab, id} | more(rest_ids, gender, rest_prefs, [id | next_ids]), count - 1]

#       :"$end_of_table" ->
#         []
#     end
#   end
# end
