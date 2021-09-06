import Config

config :t, T.Accounts.UserNotifier, adapter: T.Accounts.LocalUserNotifier
config :t, T.Media.Client, adapter: T.Media.S3Client
config :t, T.Bot, adapter: T.Bot.API
config :t, T.PushNotifications.APNS, adapter: T.PushNotifications.APNS.Pigeon
config :t, T.Twilio, adapter: T.Twilio.HTTP