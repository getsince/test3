alias T.Feeds.FeedCache

{:ok, _pid} = FeedCache.start_link([])

story = [
  %{
    "background" => %{"s3_key" => "1e08a6a1-c99a-4ac0-bc75-aef5e03fab8a"},
    "labels" => [
      %{
        "answer" => "Moscow",
        "position" => [16.39473684210526, 653.8865836791149],
        "question" => "city",
        "rotation" => 0,
        "value" => "Moscow",
        "zoom" => 1
      },
      %{
        "answer" => "1992-06-15T09:29:34Z",
        "position" => [17.76315789473683, 711.5131396957124],
        "question" => "birthdate",
        "rotation" => 0,
        "value" => "29",
        "zoom" => 1
      },
      %{
        "answer" => "marketing",
        "position" => [17.894736842105278, 768.5200553250346],
        "question" => "occupation",
        "rotation" => 0,
        "value" => "marketing",
        "zoom" => 1
      }
    ],
    "size" => [414, 896]
  },
  %{
    "background" => %{"s3_key" => "7b2ee4ac-f52f-4428-8da5-7538cab82ca2"},
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
    "size" => [414, 896]
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

story = :erlang.term_to_binary(story)

# binary story (:erlang.term_to_binary(story))
# 5 MB for 10_000 -> 100 MB for 200_000 -> 1 GB for 2_000_000

# map story (story)
# 50 MB for 10_000 -> 100 MB for 20_000 -> 1 GB for 200_000

memory = fn -> "#{Float.round(:erlang.memory(:total) / 1000_000, 2)}MB" end

IO.puts("total memory before insert: #{memory.()}")

1..3000
|> Enum.map(fn _ ->
  user_id = Ecto.Bigflake.UUID.bingenerate()
  session_id = Ecto.Bigflake.UUID.bingenerate()
  {user_id, session_id, %{gender: "M", preferences: ["F"], name: "Ruslan", story: story}}
end)
|> FeedCache.put_many_users()

1..3000
|> Enum.map(fn _ ->
  user_id = Ecto.Bigflake.UUID.bingenerate()
  session_id = Ecto.Bigflake.UUID.bingenerate()
  {user_id, session_id, %{gender: "F", preferences: ["M", "F"], name: "Ruslan", story: story}}
end)
|> FeedCache.put_many_users()

1..3000
|> Enum.map(fn _ ->
  user_id = Ecto.Bigflake.UUID.bingenerate()
  session_id = Ecto.Bigflake.UUID.bingenerate()
  {user_id, session_id, %{gender: "M", preferences: ["M"], name: "Ruslan", story: story}}
end)
|> FeedCache.put_many_users()

no_filter = MapSet.new()

{cursor10, _feed} = FeedCache.feed_init("F", ["M"], 10, no_filter)
{cursor100, _feed} = FeedCache.feed_init("F", ["M"], 100, no_filter)
{cursor1000, _feed} = FeedCache.feed_init("F", ["M"], 1000, no_filter)
{multi_cursor10, _feed} = FeedCache.feed_init("F", ["M", "F"], 10, no_filter)

IO.puts("total memory after insert before gc: #{memory.()}")

Enum.each(Process.list(), fn pid -> :erlang.garbage_collect(pid) end)

IO.puts("total memory after gc: #{memory.()}\n")

Benchee.run(
  %{
    "feed_init" => fn -> FeedCache.feed_init("F", ["M"], 10, no_filter) end,
    "feed_init multi-preference" => fn -> FeedCache.feed_init("F", ["M", "F"], 10, no_filter) end,
    "feed_cont cursor=10th" => fn -> FeedCache.feed_cont(cursor10, 10, no_filter) end,
    "feed_cont cursor=100th" => fn -> FeedCache.feed_cont(cursor100, 10, no_filter) end,
    "feed_cont cursor=1000th" => fn -> FeedCache.feed_cont(cursor1000, 10, no_filter) end,
    "feed_cont multi-preference cursor=10th" => fn ->
      FeedCache.feed_cont(multi_cursor10, 10, no_filter)
    end
  },
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}]
)
