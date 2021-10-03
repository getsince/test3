defmodule T.Feeds.FeedCacheTest do
  use ExUnit.Case
  alias T.Feeds.FeedCache

  setup do
    start_supervised!(FeedCache)
    :ok
  end

  test "empty tables" do
    no_filter = MapSet.new()

    assert {<<_cursor::18-bytes>>, []} =
             FeedCache.feed_init(_my_gender = "F", _my_preference = ["F"], _limit = 10, no_filter)

    assert {<<_cursor::36-bytes>>, []} =
             FeedCache.feed_init(
               _my_gender = "F",
               _my_preference = ["F", "M"],
               _limit = 10,
               no_filter
             )

    assert {<<_cursor::54-bytes>>, []} =
             FeedCache.feed_init(
               _my_gender = "F",
               _my_preference = ["F", "M", "N"],
               _limit = 10,
               no_filter
             )
  end

  test "with ending tables" do
    %{user_id: user_id, session_id: session_id} = fake_user()
    no_filter = MapSet.new()

    assert {cursor, feed} =
             FeedCache.feed_init(
               _my_gender = "F",
               _my_preference = ["M"],
               _limit = 10,
               no_filter
             )

    assert cursor == "MF" <> session_id
    assert feed == [{user_id, "John", "M", [%{"some" => "story"}]}]
    assert {^cursor, []} = FeedCache.feed_cont(cursor, _count = 10, no_filter)
  end

  test "filter" do
    %{user_id: user_id, session_id: session_id} = fake_user()

    assert {cursor, []} =
             FeedCache.feed_init(
               _my_gender = "F",
               _my_preference = ["M"],
               _limit = 10,
               _filter = MapSet.new([user_id])
             )

    assert cursor == "MF" <> session_id
  end

  defp fake_user(opts \\ []) do
    user_id = Ecto.Bigflake.UUID.bingenerate()
    session_id = Ecto.Bigflake.UUID.bingenerate()

    data = %{
      gender: opts[:gender] || "M",
      preferences: opts[:preferences] || ["F"],
      name: opts[:name] || "John",
      story: opts[:story] || [%{"some" => "story"}]
    }

    :ok = FeedCache.put_user(user_id, session_id, data)
    %{user_id: user_id, session_id: session_id}
  end
end
