defmodule T.Calls.Topics do
  @moduledoc false

  @external_resource "priv/call_topics"

  @topics_by_locale File.ls!("priv/call_topics")
                    |> Enum.map(fn filename ->
                      topics =
                        Path.join("priv/call_topics", filename)
                        |> File.stream!()
                        |> Enum.map(fn line -> String.trim(line) end)
                        |> Enum.reject(fn line -> line == "" end)

                      {String.trim_trailing(filename, ".txt"), topics}
                    end)

  @spec list_topics(String.t()) :: [String.t()]
  def list_topics(locale)

  @spec topics_json_fragment(String.t()) :: Jason.Fragment.t()
  def topics_json_fragment(locale)

  for {locale, topics} <- @topics_by_locale do
    def list_topics(unquote(locale)), do: unquote(topics)

    json = Jason.encode!(topics)
    def topics_json_fragment(unquote(locale)), do: Jason.Fragment.new(unquote(json))
  end

  [_ | _] = en_topics = :proplists.get_value("en", @topics_by_locale)
  def list_topics(_locale), do: unquote(en_topics)

  json = Jason.encode!(en_topics)
  def topics_json_fragment(_locale), do: Jason.Fragment.new(unquote(json))
end
