T.CallTopics.start_link([])

Benchee.run(
  %{
    "encode ets topics" => fn ->
      Jason.encode_to_iodata!(%{"topics" => T.CallTopics.locale_topics("en")})
    end
  },
  memory_time: 2
)
