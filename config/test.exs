import Config

config :since, Since.Media.Client, adapter: StubMediaClient
config :since, Since.Bot, adapter: StubBot
config :since, Since.PushNotifications.APNS, adapter: MockAPNS
config :since, Since.Accounts.AppleSignIn, adapter: StubAppleSignIn
