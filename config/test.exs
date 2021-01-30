import Config

config :t, T.Accounts.UserNotifier, adapter: MockUserNotifier
config :t, T.Media.RemoteStorage, adapter: MockRemoteStorage
