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

  test "decode_story/1" do
    story = <<
      # "s3"
      115,
      51,
      # s3 key size
      16,
      # s3 key
      30,
      8,
      166,
      161,
      201,
      154,
      74,
      192,
      188,
      117,
      174,
      245,
      224,
      63,
      171,
      138,
      # page dimensions
      # x
      414::16,
      # y
      896::16,
      # label1
      # labels count
      # 3::8,
      # type = question
      0::4,
      # key size
      4::12,
      # "city"
      99,
      105,
      116,
      121,
      # type = answer
      1::4,
      # key size
      6::12,
      # "Moscow"
      77,
      111,
      115,
      99,
      111,
      119,
      # type = position
      2::4,
      # key size
      8::12,
      16.39473684210526::32,
      653.8865836791149::32,
      # label1
      # type = question
      0::4,
      # key size
      4::12,
      # "city"
      99,
      105,
      116,
      121,
      # type = answer
      1::4,
      # key size
      6::12,
      # "Moscow"
      77,
      111,
      115,
      99,
      111,
      119,
      # type = position
      2::4,
      # key size
      8::12,
      16.39473684210526::32,
      653.8865836791149::32,
      # label1
      # type = question
      0::4,
      # key size
      4::12,
      # "city"
      99,
      105,
      116,
      121,
      # type = answer
      1::4,
      # key size
      6::12,
      # "Moscow"
      77,
      111,
      115,
      99,
      111,
      119,
      # type = position
      2::4,
      # key size
      8::12,
      16.39473684210526::32,
      653.8865836791149::32,
      # "s3"
      115,
      51,
      # s3 key size
      16,
      # s3 key
      30,
      8,
      166,
      161,
      201,
      154,
      74,
      192,
      188,
      117,
      174,
      245,
      224,
      63,
      171,
      138,
      # page dimensions
      # x
      414::16,
      # y
      896::16,
      # label1
      # type = question
      0::4,
      # key size
      4::12,
      # "city"
      99,
      105,
      116,
      121,
      # type = answer
      1::4,
      # key size
      6::12,
      # "Moscow"
      77,
      111,
      115,
      99,
      111,
      119,
      # type = position
      2::4,
      # key size
      8::12,
      16.39473684210526::32,
      653.8865836791149::32,
      # label1
      # type = question
      0::4,
      # key size
      4::12,
      # "city"
      99,
      105,
      116,
      121,
      # type = answer
      1::4,
      # key size
      6::12,
      # "Moscow"
      77,
      111,
      115,
      99,
      111,
      119,
      # type = position
      2::4,
      # key size
      8::12,
      16.39473684210526::32,
      653.8865836791149::32,
      # label1
      # type = question
      0::4,
      # key size
      4::12,
      # "city"
      99,
      105,
      116,
      121,
      # type = answer
      1::4,
      # key size
      6::12,
      # "Moscow"
      77,
      111,
      115,
      99,
      111,
      119,
      # type = position
      2::4,
      # key size
      8::12,
      16.39473684210526::32,
      653.8865836791149::32,
      # "s3"
      115,
      51,
      # s3 key size
      16,
      # s3 key
      30,
      8,
      166,
      161,
      201,
      154,
      74,
      192,
      188,
      117,
      174,
      245,
      224,
      63,
      171,
      138,
      # page dimensions
      # x
      414::16,
      # y
      896::16,
      # label1
      # type = question
      0::4,
      # key size
      4::12,
      # "city"
      99,
      105,
      116,
      121,
      # type = answer
      1::4,
      # key size
      6::12,
      # "Moscow"
      77,
      111,
      115,
      99,
      111,
      119,
      # type = position
      2::4,
      # key size
      8::12,
      16.39473684210526::32,
      653.8865836791149::32,
      # label1
      # type = question
      0::4,
      # key size
      4::12,
      # "city"
      99,
      105,
      116,
      121,
      # type = answer
      1::4,
      # key size
      6::12,
      # "Moscow"
      77,
      111,
      115,
      99,
      111,
      119,
      # type = position
      2::4,
      # key size
      8::12,
      16.39473684210526::32,
      653.8865836791149::32,
      # label1
      # type = question
      0::4,
      # key size
      4::12,
      # "city"
      99,
      105,
      116,
      121,
      # type = answer
      1::4,
      # key size
      6::12,
      # "Moscow"
      77,
      111,
      115,
      99,
      111,
      119,
      # type = position
      2::4,
      # key size
      8::12,
      16.39473684210526::32,
      653.8865836791149::32
    >>

    assert FeedCache.decode_story(story) == [
             %{
               "background" => %{
                 "s3_key" => "1e08a6a1c99a4ac0bc75aef5e03fab8a"
               },
               "labels" => [
                 %{
                   "answer" => "Moscow",
                   "position" => [16.395, 653.887],
                   "question" => "city"
                 },
                 %{
                   "answer" => "Moscow",
                   "position" => [16.395, 653.887],
                   "question" => "city"
                 },
                 %{
                   "answer" => "Moscow",
                   "position" => [16.395, 653.887],
                   "question" => "city"
                 }
               ],
               "size" => [414, 896]
             },
             %{
               "background" => %{
                 "s3_key" => "1e08a6a1c99a4ac0bc75aef5e03fab8a"
               },
               "labels" => [
                 %{
                   "answer" => "Moscow",
                   "position" => [16.395, 653.887],
                   "question" => "city"
                 },
                 %{
                   "answer" => "Moscow",
                   "position" => [16.395, 653.887],
                   "question" => "city"
                 },
                 %{
                   "answer" => "Moscow",
                   "position" => [16.395, 653.887],
                   "question" => "city"
                 }
               ],
               "size" => [414, 896]
             },
             %{
               "background" => %{
                 "s3_key" => "1e08a6a1c99a4ac0bc75aef5e03fab8a"
               },
               "labels" => [
                 %{
                   "answer" => "Moscow",
                   "position" => [16.395, 653.887],
                   "question" => "city"
                 },
                 %{
                   "answer" => "Moscow",
                   "position" => [16.395, 653.887],
                   "question" => "city"
                 },
                 %{
                   "answer" => "Moscow",
                   "position" => [16.395, 653.887],
                   "question" => "city"
                 }
               ],
               "size" => [414, 896]
             }
           ]
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
