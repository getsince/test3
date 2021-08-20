defmodule Dev do
  alias T.PushNotifications.APNS

  def send_notification(locale \\ "en") do
    device_id = System.get_env("MY_APNS_ID")

    n =
      Gettext.with_locale(locale, fn ->
        APNS.build_notification("timeslot_started", device_id, %{})
      end)

    APNS.push_all_envs(n)
  end
end
