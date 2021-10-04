alias T.Feeds.FeedCache

{:ok, _pid} = FeedCache.start_link([])

# story = [
#   ["s3" | <<30, 8, 166, 161, 201, 154, 74, 192, 188, 117, 174, 245, 224, 63, 171, 138>>],
#   [414 | 896],
#   [["q" | "city"], ["a" | "Moscow"], ["p" | [16.39473684210526 | 653.8865836791149]]],
#   [["q" | "birthdate"], ["a" | "1992-06-15"], ["p" | [17.76315789473683 | 711.5131396957124]]],
#   [["q" | "occupation"], ["a" | "marketing"], ["p" | [17.894736842105278 | 768.5200553250346]]],
#   ["s3" | <<30, 8, 166, 161, 201, 154, 74, 192, 188, 117, 174, 245, 224, 63, 171, 138>>],
#   [414 | 896],
#   [["q" | "city"], ["a" | "Moscow"], ["p" | [16.39473684210526 | 653.8865836791149]]],
#   [["q" | "birthdate"], ["a" | "1992-06-15"], ["p" | [17.76315789473683 | 711.5131396957124]]],
#   [["q" | "occupation"], ["a" | "marketing"], ["p" | [17.894736842105278 | 768.5200553250346]]],
#   ["s3" | <<30, 8, 166, 161, 201, 154, 74, 192, 188, 117, 174, 245, 224, 63, 171, 138>>],
#   [414 | 896],
#   [["q" | "city"], ["a" | "Moscow"], ["p" | [16.39473684210526 | 653.8865836791149]]],
#   [["q" | "birthdate"], ["a" | "1992-06-15"], ["p" | [17.76315789473683 | 711.5131396957124]]],
#   [["q" | "occupation"], ["a" | "marketing"], ["p" | [17.894736842105278 | 768.5200553250346]]]
# ]

story =
  Jason.encode!([
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
  ])

story =
  "[{\"background\":{\"s3_key\":\"1e08a6a1c99a4ac0bc75aef5e03fab8a\"},\"labels\":[{\"answer\":\"Moscow\",\"position\":[16.395,653.887],\"question\":\"city\"},{\"answer\":\"Moscow\",\"position\":[16.395,653.887],\"question\":\"city\"},{\"answer\":\"Moscow\",\"position\":[16.395,653.887],\"question\":\"city\"}],\"size\":[414,896]},{\"background\":{\"s3_key\":\"1e08a6a1c99a4ac0bc75aef5e03fab8a\"},\"labels\":[{\"answer\":\"Moscow\",\"position\":[16.395,653.887],\"question\":\"city\"},{\"answer\":\"Moscow\",\"position\":[16.395,653.887],\"question\":\"city\"},{\"answer\":\"Moscow\",\"position\":[16.395,653.887],\"question\":\"city\"}],\"size\":[414,896]},{\"background\":{\"s3_key\":\"1e08a6a1c99a4ac0bc75aef5e03fab8a\"},\"labels\":[{\"answer\":\"Moscow\",\"position\":[16.395,653.887],\"question\":\"city\"},{\"answer\":\"Moscow\",\"position\":[16.395,653.887],\"question\":\"city\"},{\"answer\":\"Moscow\",\"position\":[16.395,653.887],\"question\":\"city\"}],\"size\":[414,896]}]"

# story = :erlang.term_to_binary(story)

# binary story (:erlang.term_to_binary(story))
# 5 MB for 10_000 -> 100 MB for 200_000 -> 1 GB for 2_000_000

# map story (story)
# 50 MB for 10_000 -> 100 MB for 20_000 -> 1 GB for 200_000

memory = fn -> "#{Float.round(:erlang.memory(:ets) / 1000_000, 2)}MB" end

IO.puts("ets memory before insert: #{memory.()}")

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

IO.puts("ets memory after insert before gc: #{memory.()}")

Enum.each(Process.list(), fn pid -> :erlang.garbage_collect(pid) end)

IO.puts("ets memory after gc: #{memory.()}\n")

# url =
#   "https://d3r9yicn85nax9.cloudfront.net/4_nhpMtPlaYOhXhMhJqQPdebmlr1sYXcgJUXDNGcixE/fit/1000/0/sm/0/aHR0cHM6Ly9zaW5jZS13aGVuLWFyZS15b3UtaGFwcHkuczMuYW1hem9uYXdzLmNvbS9hc2Rm"

# pattern = :binary.compile_pattern(~s["background":{"s3_key":"1e08a6a1c99a4ac0bc75aef5e03fab8a"}])

Benchee.run(
  %{
    # "decode_story" => fn -> Enum.each(1..10, fn _ -> FeedCache.decode_story(story) end) end,
    # "replace" => fn ->
    #   Enum.each(1..10, fn _ ->
    #     String.replace(
    #       story,
    #       pattern,
    #       "a"
    #     )
    #   end)
    # end

    "feed_init" => fn -> FeedCache.feed_init("F", ["M"], 10, no_filter) end,
    "feed_init multi-preference" => fn -> FeedCache.feed_init("F", ["M", "F"], 10, no_filter) end,
    "feed_cont cursor=10th" => fn -> FeedCache.feed_cont(cursor10, 10, no_filter) end,
    "feed_cont cursor=100th" => fn -> FeedCache.feed_cont(cursor100, 10, no_filter) end,
    "feed_cont cursor=1000th" => fn -> FeedCache.feed_cont(cursor1000, 10, no_filter) end,
    "feed_cont multi-preference cursor=10th" => fn ->
      FeedCache.feed_cont(multi_cursor10, 10, no_filter)
    end
  },
  formatters: [{Benchee.Formatters.Console, extended_statistics: true}],
  memory_time: 2
)

"/4_nhpMtPlaYOhXhMhJqQPdebmlr1sYXcgJUXDNGcixE/fit/1000/0/sm/0/aHR0cHM6Ly9zaW5jZS13aGVuLWFyZS15b3UtaGFwcHkuczMuYW1hem9uYXdzLmNvbS9hc2Rm"
# <<"/", _signature::42-bytes, "/fit/800/", _rest::bytes>> -> true
# <<"/", _signature::42-bytes, "/fit/1000/", _rest::bytes>> -> true
# <<"/", _signature::42-bytes, "/fit/1200/", _rest::bytes>> -> true
# _other -> false
