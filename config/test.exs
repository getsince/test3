import Config

config :t, T.Accounts.UserNotifier, adapter: MockUserNotifier
config :t, T.Music, adapter: MockMusic
config :t, T.Media.Client, adapter: StubMediaClient
config :t, T.Bot, adapter: MockBot
