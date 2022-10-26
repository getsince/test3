defmodule T.News do
  @moduledoc false
  import Ecto.Query

  alias T.Repo
  alias T.News.SeenNews

  import T.Cluster, only: [primary_rpc: 3]

  defp news do
    case Gettext.get_locale() do
      "ru" ->
        [
          %{
            id: 17,
            timestamp: ~U[2022-10-26 14:00:00Z],
            version: "8.0.0",
            story: [
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 1,
                    "value" => "Привет 👋 \nМы с обновлениями",
                    "center" => [156.0298520249221, 119.9119914330218],
                    "position" => [43.696518691588764, 81.24532476635514],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  },
                  %{
                    "zoom" => 0.9528107916219694,
                    "value" => "🥳 новая лента \nс удобными фильтрами",
                    "center" => [242.93051830361503, 714.9797487948225],
                    "position" => [120.43051830361503, 678.1464154614891],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "background" => %{
                  "zoom" => 0.6512980860487045,
                  "color" => "#FF782D",
                  "s3_key" => "36812f07-ce1b-41ac-b01b-a08a05141aa7",
                  "position" => [67.99687322050262, 147.15220768744666],
                  "rotation" => 12.871057923604639,
                  "video_s3_key" => "3ff36b6e-6a25-4202-894f-17558ac95ffd"
                }
              },
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 1.0199362917254977,
                    "value" => "✨ новый чат",
                    "center" => [114.29958691798977, 158.60118978049866],
                    "position" => [35.1329202513231, 134.60118978049866],
                    "rotation" => 0,
                    "alignment" => 1,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "background" => %{
                  "zoom" => 0.6573384605739353,
                  "color" => "#FF782D",
                  "s3_key" => "46f258d4-1e4a-4755-9577-6a5cf0a9ec6a",
                  "position" => [66.81900018808261, 144.60316963779928],
                  "rotation" => 17.634181896700753
                }
              },
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 1,
                    "value" => "✍️ сейчас можно написать \nинтересному человеку \nсразу",
                    "center" => [195.22797897196264, 178.51755062305293],
                    "position" => [48.3946456386293, 124.85088395638627],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "drawing" => %{
                  "lines" =>
                    "W3sicG9pbnRzIjpbWzIwOS42NjY2NTY0OTQxNDA2Miw3NzMuMzMzMzI4MjQ3MDcwMzFdLFsyMTEuNjY2NjU2NDk0MTQwNjIsNzY2LjMzMzMyODI0NzA3MDMxXSxbMjE1LjY2NjY1NjQ5NDE0MDYyLDc1OS42NjY2NTY0OTQxNDA2Ml0sWzIxOCw3NTYuNjY2NjU2NDk0MTQwNjJdLFsyMjAsNzUzLjMzMzMyODI0NzA3MDMxXSxbMjIzLjY2NjY1NjQ5NDE0MDYyLDc0N10sWzIyNy42NjY2NTY0OTQxNDA2Miw3NDAuMzMzMzI4MjQ3MDcwMzFdLFsyMzEuMzMzMzI4MjQ3MDcwMzEsNzMzLjMzMzMyODI0NzA3MDMxXSxbMjM0LjY2NjY1NjQ5NDE0MDYyLDcyNy4zMzMzMjgyNDcwNzAzMV0sWzIzOC4zMzMzMjgyNDcwNzAzMSw3MjEuMzMzMzI4MjQ3MDcwMzFdLFsyNDEuMzMzMzI4MjQ3MDcwMzEsNzE2XSxbMjQzLjMzMzMyODI0NzA3MDMxLDcxMl0sWzI0NSw3MDkuMzMzMzI4MjQ3MDcwMzFdLFsyNDUuNjY2NjU2NDk0MTQwNjIsNzA4LjMzMzMyODI0NzA3MDMxXSxbMjQ1LjY2NjY1NjQ5NDE0MDYyLDcwOF0sWzI0NS4zMzMzMjgyNDcwNzAzMSw3MDcuNjY2NjU2NDk0MTQwNjJdLFsyNDUsNzA3LjMzMzMyODI0NzA3MDMxXSxbMjQ0LjY2NjY1NjQ5NDE0MDYyLDcwN10sWzI0NC42NjY2NTY0OTQxNDA2Miw3MDYuNjY2NjU2NDk0MTQwNjJdLFsyNDQuMzMzMzI4MjQ3MDcwMzEsNzA2LjY2NjY1NjQ5NDE0MDYyXSxbMjQ0LDcwNi42NjY2NTY0OTQxNDA2Ml0sWzI0Mi42NjY2NTY0OTQxNDA2Miw3MDYuNjY2NjU2NDk0MTQwNjJdLFsyNDEsNzA3LjY2NjY1NjQ5NDE0MDYyXSxbMjM3LjY2NjY1NjQ5NDE0MDYyLDcxMV0sWzIzNCw3MTQuMzMzMzI4MjQ3MDcwMzFdLFsyMzEuMzMzMzI4MjQ3MDcwMzEsNzE3LjMzMzMyODI0NzA3MDMxXSxbMjI5LDcxOS4zMzMzMjgyNDcwNzAzMV0sWzIyNy42NjY2NTY0OTQxNDA2Miw3MjAuNjY2NjU2NDk0MTQwNjJdLFsyMjcuMzMzMzI4MjQ3MDcwMzEsNzIxLjMzMzMyODI0NzA3MDMxXSxbMjI3LjY2NjY1NjQ5NDE0MDYyLDcyMS4zMzMzMjgyNDcwNzAzMV0sWzIzMC42NjY2NTY0OTQxNDA2Miw3MTldLFsyMzQuMzMzMzI4MjQ3MDcwMzEsNzE1LjMzMzMyODI0NzA3MDMxXSxbMjM5LjMzMzMyODI0NzA3MDMxLDcxMS4zMzMzMjgyNDcwNzAzMV0sWzI0My4zMzMzMjgyNDcwNzAzMSw3MDcuNjY2NjU2NDk0MTQwNjJdLFsyNDYuNjY2NjU2NDk0MTQwNjIsNzA1XSxbMjQ5LDcwMy42NjY2NTY0OTQxNDA2Ml0sWzI0OS42NjY2NTY0OTQxNDA2Miw3MDMuNjY2NjU2NDk0MTQwNjJdLFsyNTAsNzAzLjY2NjY1NjQ5NDE0MDYyXSxbMjUwLDcwNS42NjY2NTY0OTQxNDA2Ml0sWzI1MCw3MTBdLFsyNTAsNzE2XSxbMjUwLDcyMy42NjY2NTY0OTQxNDA2Ml0sWzI1MSw3MzddXSwic3Ryb2tlX2NvbG9yIjoiIzExMTAxMCIsInN0cm9rZV93aWR0aCI6NX1d"
                },
                "background" => %{
                  "zoom" => 0.6430794317308413,
                  "color" => "#FF782D",
                  "s3_key" => "be5c3b2e-4964-4630-84db-50cebed8a11e",
                  "position" => [208.79853243745788, 451.8614394287551],
                  "rotation" => 10.207734167975927
                }
              }
            ]
          }
        ]

      _ ->
        [
          %{
            id: 17,
            timestamp: ~U[2022-10-26 14:00:00Z],
            version: "8.0.0",
            story: [
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 1,
                    "value" => "Hey 👋 \nIt’s a new update",
                    "center" => [147.72517642582665, 124.03600160554782],
                    "position" => [53.725176425826646, 85.36933493888117],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  },
                  %{
                    "zoom" => 1,
                    "value" => "🥳 new feed\n with handy filters",
                    "center" => [239.92479750778813, 721.9119914330217],
                    "position" => [141.0914641744548, 683.2453247663551],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "background" => %{
                  "zoom" => 0.6437926802213981,
                  "color" => "#FF782D",
                  "s3_key" => "55d40835-fed3-4dbe-85e9-3e9f37546807",
                  "position" => [69.46042735682737, 150.31948894657],
                  "rotation" => 14.509230027169107,
                  "video_s3_key" => "11b0438a-1382-441e-b944-a340da614f6e"
                }
              },
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 1,
                    "value" => "✨ new chat",
                    "center" => [114.35048525040752, 141.97001998264398],
                    "position" => [42.183818583740845, 118.47001998264398],
                    "rotation" => 0,
                    "alignment" => 1,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "background" => %{
                  "zoom" => 0.6283846238912895,
                  "color" => "#FF782D",
                  "s3_key" => "71aa72d8-e833-4d8f-8d0d-0ce1311a6ee8",
                  "position" => [144.92999668239713, 313.64337743575174],
                  "rotation" => 13.038451156159331
                }
              },
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 1,
                    "value" => "✍️ now you can connect \nwith interesting person\n straightaway",
                    "center" => [159.47804008507669, 162.97487887012323],
                    "position" => [28.811373418410028, 109.30821220345658],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "drawing" => %{
                  "lines" =>
                    "W3sicG9pbnRzIjpbWzIxMC4zMzMzMjgyNDcwNzAzMSw3NjkuMzMzMzI4MjQ3MDcwMzFdLFsyMDkuMzMzMzI4MjQ3MDcwMzEsNzY3LjMzMzMyODI0NzA3MDMxXSxbMjE0LDc2MC42NjY2NTY0OTQxNDA2Ml0sWzIxOS4zMzMzMjgyNDcwNzAzMSw3NTIuNjY2NjU2NDk0MTQwNjJdLFsyMjQuMzMzMzI4MjQ3MDcwMzEsNzQzLjY2NjY1NjQ5NDE0MDYyXSxbMjI4LjY2NjY1NjQ5NDE0MDYyLDczNS4zMzMzMjgyNDcwNzAzMV0sWzIzMi4zMzMzMjgyNDcwNzAzMSw3MjguMzMzMzI4MjQ3MDcwMzFdLFsyMzYuMzMzMzI4MjQ3MDcwMzEsNzIyLjMzMzMyODI0NzA3MDMxXSxbMjM5LDcxNy42NjY2NTY0OTQxNDA2Ml0sWzI0MC42NjY2NTY0OTQxNDA2Miw3MTUuMzMzMzI4MjQ3MDcwMzFdLFsyNDEsNzE1LjMzMzMyODI0NzA3MDMxXSxbMjQxLDcxNS42NjY2NTY0OTQxNDA2Ml0sWzIzOS42NjY2NTY0OTQxNDA2Miw3MTcuNjY2NjU2NDk0MTQwNjJdLFsyMzYsNzIwXSxbMjMxLjY2NjY1NjQ5NDE0MDYyLDcyMi42NjY2NTY0OTQxNDA2Ml0sWzIyNyw3MjUuMzMzMzI4MjQ3MDcwMzFdLFsyMjIuNjY2NjU2NDk0MTQwNjIsNzI3LjY2NjY1NjQ5NDE0MDYyXSxbMjE5LDczMF0sWzIxNS42NjY2NTY0OTQxNDA2Miw3MzJdLFsyMTMuMzMzMzI4MjQ3MDcwMzEsNzM0XSxbMjEyLjMzMzMyODI0NzA3MDMxLDczNC42NjY2NTY0OTQxNDA2Ml0sWzIxMi4zMzMzMjgyNDcwNzAzMSw3MzVdLFsyMTMuMzMzMzI4MjQ3MDcwMzEsNzM1XSxbMjE3LjY2NjY1NjQ5NDE0MDYyLDczMS42NjY2NTY0OTQxNDA2Ml0sWzIyMi4zMzMzMjgyNDcwNzAzMSw3MjhdLFsyMjcuNjY2NjU2NDk0MTQwNjIsNzIzLjY2NjY1NjQ5NDE0MDYyXSxbMjMyLjY2NjY1NjQ5NDE0MDYyLDcyMC4zMzMzMjgyNDcwNzAzMV0sWzIzNyw3MTcuNjY2NjU2NDk0MTQwNjJdLFsyMzkuNjY2NjU2NDk0MTQwNjIsNzE3XSxbMjQwLjMzMzMyODI0NzA3MDMxLDcxN10sWzI0MC42NjY2NTY0OTQxNDA2Miw3MTkuMzMzMzI4MjQ3MDcwMzFdLFsyNDAuNjY2NjU2NDk0MTQwNjIsNzM0LjMzMzMyODI0NzA3MDMxXSxbMjQwLjY2NjY1NjQ5NDE0MDYyLDc0NS42NjY2NTY0OTQxNDA2Ml1dLCJzdHJva2VfY29sb3IiOiIjMTExMDEwIiwic3Ryb2tlX3dpZHRoIjo1fV0="
                },
                "background" => %{
                  "zoom" => 0.6749995342860374,
                  "color" => "#FF782D",
                  "s3_key" => "facc75fa-de98-4ee5-9807-398b6d0faec7",
                  "position" => [126.75018162844538, 274.30039306258436],
                  "rotation" => 15.128312665369187
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
    primary_rpc(__MODULE__, :local_mark_seen, [user_id, news_story_id])
  end

  @doc false
  def local_mark_seen(user_id, news_story_id) do
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
