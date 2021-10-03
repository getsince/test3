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
1..10000
|> Enum.map(fn _ ->
  user_id = Ecto.Bigflake.UUID.bingenerate()
  session_id = Ecto.Bigflake.UUID.bingenerate()
  {user_id, session_id, %{gender: "M", preferences: ["F"], name: "Ruslan", story: story}}
end)
|> FeedCache.put_many_users()

# {[{_, cursor10}], _} = FeedCache.fetch_feed(nil, "F", ["M"], 10)
# {[{_, cursor100}], _} = FeedCache.fetch_feed(nil, "F", ["M"], 100)
# {[{_, cursor1000}], _} = FeedCache.fetch_feed(nil, "F", ["M"], 1000)

{cursor10, _} = FeedCache.fetch_feed(nil, "F", ["M"], 10)
{cursor100, _} = FeedCache.fetch_feed(nil, "F", ["M"], 100)
{cursor1000, _} = FeedCache.fetch_feed(nil, "F", ["M"], 1000)

Enum.each(Process.list(), fn pid -> :erlang.garbage_collect(pid) end)

Benchee.run(%{
  "count=10 cursor=nil" => fn -> FeedCache.fetch_feed(nil, "F", ["M"], 10) end,
  "count=10 cursor=10th" => fn -> FeedCache.fetch_feed(cursor10, "F", ["M"], 10) end,
  "count=10 cursor=100th" => fn -> FeedCache.fetch_feed(cursor100, "F", ["M"], 10) end,
  "count=10 cursor=1000th" => fn -> FeedCache.fetch_feed(cursor1000, "F", ["M"], 10) end
})
