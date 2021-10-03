defmodule T.Feeds.FeedCacheTest do
  use ExUnit.Case
  alias T.Feeds.FeedCache

  setup do
    start_supervised!(FeedCache)
    :ok
  end

  test "empty tables" do
    assert {[active_FF: <<0::128>>], []} =
             FeedCache.fetch_feed(_my_gender = "F", _my_preference = ["F"])

    assert {[active_MF: <<0::128>>, active_FF: <<0::128>>], []} =
             FeedCache.fetch_feed(_my_gender = "F", _my_preference = ["F", "M"])

    assert {[active_NF: <<0::128>>, active_MF: <<0::128>>, active_FF: <<0::128>>], []} =
             FeedCache.fetch_feed(_my_gender = "F", _my_preference = ["F", "M", "N"])
  end

  test "with ending tables" do
    user_id = Ecto.Bigflake.UUID.bingenerate()
    session_id = Ecto.Bigflake.UUID.bingenerate()
    data = %{gender: "M", preferences: ["F"], name: "John", story: [%{"some" => "story"}]}

    :ok = FeedCache.put_user(user_id, session_id, data)

    assert {cursor, feed} = FeedCache.fetch_feed(_my_gender = "F", _my_preference = ["M"])
    assert cursor == [active_MF: session_id]
    assert feed == [{user_id, "John", "M", [%{"some" => "story"}]}]

    assert {cursor, []} = FeedCache.fetch_feed(session_id, "F", ["M"])
    assert cursor == [active_MF: session_id]
  end
end
