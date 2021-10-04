alias T.Feeds.FeedCache

{:ok, _pid} = FeedCache.start_link([])

story = [
  ["s3" | <<30, 8, 166, 161, 201, 154, 74, 192, 188, 117, 174, 245, 224, 63, 171, 138>>],
  [414 | 896],
  [["q" | "city"], ["a" | "Moscow"], ["p" | [16.39473684210526 | 653.8865836791149]]],
  [["q" | "birthdate"], ["a" | "1992-06-15"], ["p" | [17.76315789473683 | 711.5131396957124]]],
  [["q" | "occupation"], ["a" | "marketing"], ["p" | [17.894736842105278 | 768.5200553250346]]],
  ["s3" | <<30, 8, 166, 161, 201, 154, 74, 192, 188, 117, 174, 245, 224, 63, 171, 138>>],
  [414 | 896],
  [["q" | "city"], ["a" | "Moscow"], ["p" | [16.39473684210526 | 653.8865836791149]]],
  [["q" | "birthdate"], ["a" | "1992-06-15"], ["p" | [17.76315789473683 | 711.5131396957124]]],
  [["q" | "occupation"], ["a" | "marketing"], ["p" | [17.894736842105278 | 768.5200553250346]]],
  ["s3" | <<30, 8, 166, 161, 201, 154, 74, 192, 188, 117, 174, 245, 224, 63, 171, 138>>],
  [414 | 896],
  [["q" | "city"], ["a" | "Moscow"], ["p" | [16.39473684210526 | 653.8865836791149]]],
  [["q" | "birthdate"], ["a" | "1992-06-15"], ["p" | [17.76315789473683 | 711.5131396957124]]],
  [["q" | "occupation"], ["a" | "marketing"], ["p" | [17.894736842105278 | 768.5200553250346]]]
]

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

Benchee.run(
  %{
    "decode_story" => fn -> Enum.each(1..10, fn _ -> FeedCache.decode_story(story) end) end,
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
