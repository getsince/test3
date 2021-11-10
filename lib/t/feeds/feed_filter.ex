defmodule T.Feeds.FeedFilter do
  @enforce_keys [:genders]
  defstruct [:genders, :min_age, :max_age, :distance]
end
