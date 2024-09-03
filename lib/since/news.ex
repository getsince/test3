defmodule Since.News do
  @moduledoc false
  import Ecto.Query

  alias Since.Repo
  alias Since.News.SeenNews

  defp news do
    case Gettext.get_locale() do
      "ru" ->
        [
          %{
            id: 20,
            timestamp: ~U[2022-12-14 10:00:00Z],
            version: "8.3.0",
            story: [
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 0.8028763539650605,
                    "value" => "Привет 👋 В новом \nапдейте:",
                    "center" => [110.6253546589989, 133.38667333596018],
                    "position" => [22.792021325665573, 102.05334000262685],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  },
                  %{
                    "zoom" => 0.851172271600246,
                    "value" => "Новая фуллскрин лента \nс пользователями ❤️‍🔥",
                    "center" => [232.40020715224574, 717.440643873187],
                    "position" => [119.23354048557907, 684.2739772065204],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "background" => %{
                  "zoom" => 0.6502861933878576,
                  "color" => "#AECFFF",
                  "s3_key" => "f15cef2b-b99f-49e1-9f3a-a73180d9dfe9",
                  "position" => [136.38838457873555, 295.15845278064813],
                  "rotation" => 16.258649907993558
                }
              },
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 0.7921290294611806,
                    "value" =>
                      "Since Premium 💎 — играй без \nлимитов и узнай, кто поставил тебе \nлайк 👀",
                    "center" => [160.61191598471876, 142.94891385338292],
                    "position" => [9.945249318052106, 99.94891385338292],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "background" => %{
                  "zoom" => 0.6880537910246307,
                  "color" => "#C7E36E",
                  "s3_key" => "5750ae8d-5952-481e-8126-783d36b06bd8",
                  "position" => [121.65902150039406, 263.28260037521176],
                  "rotation" => 19.973404846363323
                }
              },
              %{
                "size" => [390, 844],
                "labels" => [],
                "background" => %{
                  "zoom" => 0.7149814417382633,
                  "color" => "#111010",
                  "s3_key" => "a3338ab4-c6d0-4987-9f6f-fe6702544519",
                  "position" => [111.1572377220773, 240.55566317290578],
                  "rotation" => 11.407453185183293,
                  "video_s3_key" => "2eaf2235-4e78-49d0-87e1-15b45921b0ae"
                }
              }
            ]
          }
        ]

      _ ->
        [
          %{
            id: 20,
            timestamp: ~U[2022-12-14 10:00:00Z],
            version: "8.3.0",
            story: [
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 0.7666090812511713,
                    "value" => "Hey 👋 In our new update:",
                    "center" => [114.5226499775388, 120.57277384970952],
                    "position" => [10.2638149273795, 102.557460440307],
                    "rotation" => 0,
                    "alignment" => 1,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  },
                  %{
                    "zoom" => 0.7922770082950592,
                    "value" => "New full screen Feed with users ❤️‍🔥",
                    "center" => [224.1666514078778, 702.9999847412109],
                    "position" => [82.6666514078778, 683.9999847412109],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "background" => %{
                  "zoom" => 0.6500012936414258,
                  "color" => "#C2C2C5",
                  "s3_key" => "b9c7b0fd-5504-4772-9d50-e29da07b9c12",
                  "position" => [68.24974773992197, 147.6994540833183],
                  "rotation" => 8.087927233084573
                }
              },
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 0.9341749443210824,
                    "value" => "Since Premium 💎 ",
                    "center" => [104.48331948778716, 124.16609463623656],
                    "position" => [10.131650111357828, 102.21298344469113],
                    "rotation" => 0,
                    "alignment" => 1,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  },
                  %{
                    "zoom" => 0.8817104395110301,
                    "value" => "Play without limits. Find out \nwho likes you 👀",
                    "center" => [236.07814657621296, 717.8197177448103],
                    "position" => [107.34842240760256, 683.7269140837171],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "background" => %{
                  "zoom" => 0.7288773691847487,
                  "color" => "#C8E46E",
                  "s3_key" => "e8f20fcf-8670-44a5-99fa-ceca255a4f7e",
                  "position" => [52.868913008974005, 114.41375020403609],
                  "rotation" => 14.488575548617757
                }
              },
              %{
                "size" => [390, 844],
                "labels" => [],
                "background" => %{
                  "zoom" => 0.7748900947519992,
                  "color" => "#1D1B1E",
                  "s3_key" => "95f60bb7-1de0-464b-9700-6e31eee1da6a",
                  "position" => [43.89643152336015, 94.99638001465632],
                  "rotation" => 13.167002387090731,
                  "video_s3_key" => "e48ab2b5-31d7-4cd8-a8c2-5a6f01a1c0c0"
                }
              }
            ]
          }
        ]
    end
  end

  defp last_id do
    case List.last(news()) do
      nil -> 0
      last_news -> last_news.id
    end
  end

  @spec list_news(Ecto.Bigflake.UUID.t(), Version.t()) :: [%{id: pos_integer(), story: [map]}]
  def list_news(user_id, version) do
    last_seen_id = last_seen_id(user_id) || 0
    user_inserted_at = datetime(user_id)

    Enum.filter(news(), fn news_story -> news_story.id > last_seen_id end)
    |> Enum.filter(fn news_story ->
      DateTime.compare(user_inserted_at, news_story.timestamp) == :lt
    end)
    |> Enum.filter(fn news_story ->
      Version.compare(version, news_story.version) in [:eq, :gt]
    end)
  end

  def mark_seen(user_id, news_story_id \\ last_id()) do
    Repo.transaction(fn ->
      last_seen_id = last_seen_id(user_id) || 0

      if last_seen_id < news_story_id do
        Repo.insert_all(SeenNews, [%{user_id: user_id, last_id: news_story_id}],
          on_conflict: {:replace, [:last_id]},
          conflict_target: [:user_id]
        )
      end
    end)
  end

  @spec last_seen_id(Ecto.Bigflake.UUID.t()) :: pos_integer() | nil
  defp last_seen_id(user_id) do
    SeenNews |> where(user_id: ^user_id) |> select([n], n.last_id) |> Repo.one()
  end

  defp datetime(<<_::288>> = uuid) do
    datetime(Ecto.Bigflake.UUID.dump!(uuid))
  end

  defp datetime(<<unix::64, _rest::64>>) do
    unix |> DateTime.from_unix!(:millisecond) |> DateTime.truncate(:second)
  end
end
