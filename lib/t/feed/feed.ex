defmodule T.Feed do
  alias T.Repo

  def subscribe_to_matched do
    Phoenix.PubSub.subscribe(T.PubSub, to_string(__MODULE__))
  end

  def get_feed(user_id) when is_binary(user_id) do
  end
end
