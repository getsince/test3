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

  test "compress" do


    [
      [414 | 896],
      ["s3" | "1e08a6a1-c99a-4ac0-bc75-aef5e03fab8a"],
      [["q" | "city"], ["a" | "Moscow"], ["p" | [16.39473684210526 | 653.8865836791149]]],
      [["q" | "birthdate"], ["a" | "1992-06-15"], ["p" | [17.76315789473683 | 711.5131396957124]]],
      [["q" | "occupation"], ["a" | "marketing"], ["p" | [17.894736842105278 | 768.5200553250346] ]],


      %{
        "background" => %{"s3_key" => },
        "labels" => [
          %{
            "answer" => "dog",
            "position" => [32.45421914384576, 508.55878284923926],
            "question" => "pets",
            "rotation" => 0,
            "value" => "dog",
            "zoom" => 1
          },
          %{
            "answer" => "",
            "position" => [30.007430073955632, 125.42931999400341],
            "question" => "height",
            "rotation" => -0.1968919380719123,
            "value" => "169 cm",
            "zoom" => 0.929552717754467
          }
        ],
        "size" => []
      },
      %{
        "background" => %{"s3_key" => "030cf497-eabc-40e8-9e25-22f0549d5828"},
        "labels" => [
          %{
            "answer" => "politics",
            "position" => [255.18867086246476, 172.7136929460581],
            "question" => "interests",
            "rotation" => 0,
            "value" => "politics",
            "zoom" => 1
          },
          %{
            "answer" => "culture and art",
            "position" => [188.0263157894737, 231.47884213914443],
            "question" => "books",
            "rotation" => 0,
            "value" => "culture and art",
            "zoom" => 1
          }
        ],
        "size" => [414, 896]
      },
      %{
        "background" => %{"s3_key" => "8ecc0c2c-89fb-437f-bfae-4893cba3c7fc"},
        "labels" => [
          %{
            "answer" => "The Sopranos",
            "position" => [9.407094262700014, 362.32365145228215],
            "question" => "tv_shows",
            "rotation" => 0,
            "value" => "The Sopranos",
            "zoom" => 1
          }
        ],
        "size" => [414, 896]
      }
    ]

    assert <<_::128>> = compressed = FeedCache.compress(story)
    assert FeedCache.decompress(compressed) == story
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
