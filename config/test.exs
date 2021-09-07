import Config

config :t, T.Media.Client, adapter: StubMediaClient
config :t, T.Bot, adapter: StubBot
config :t, T.PushNotifications.APNS, adapter: MockAPNS
config :t, T.Twilio, adapter: StubTwilio
