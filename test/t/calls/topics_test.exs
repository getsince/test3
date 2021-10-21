defmodule T.Calls.TopicsTest do
  use ExUnit.Case, async: true
  alias T.Calls.Topics

  describe "topics_json_fragment/1" do
    test "returns encodable fragment for en" do
      %Jason.Fragment{} = fragment = Topics.topics_json_fragment("en")
      assert %{"topics" => topics} = encode_decode(%{"topics" => fragment})
      validate_topics(topics, "en")
    end

    test "returns encodable fragment for ru" do
      %Jason.Fragment{} = fragment = Topics.topics_json_fragment("ru")
      assert %{"topics" => topics} = encode_decode(%{"topics" => fragment})
      validate_topics(topics, "ru")
    end

    test "fallbacks to en if for unknown locale" do
      %Jason.Fragment{} = fragment = Topics.topics_json_fragment("ja")
      assert %{"topics" => topics} = encode_decode(%{"topics" => fragment})
      validate_topics(topics, "en")
    end
  end

  defp encode_decode(term), do: term |> Jason.encode!() |> Jason.decode!()

  defp validate_topics(topics, locale) do
    assert topics == Enum.uniq(topics)
    assert length(topics) > 10
    assert topics == Topics.list_topics(locale)
  end
end
