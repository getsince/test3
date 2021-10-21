Benchee.run(
  %{
    "encode plain topics" => fn ->
      Jason.encode_to_iodata!(%{"topics" => T.Calls.Topics.list_topics("en")})
    end,
    "encode fragment topics" => fn ->
      Jason.encode_to_iodata!(%{"topics" => T.Calls.Topics.topics_json_fragment("en")})
    end
  },
  memory_time: 2
)
