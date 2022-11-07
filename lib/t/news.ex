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
                    "center" => [156.08955607476628, 119.73597429906539],
                    "position" => [43.75622274143295, 81.06930763239873],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  },
                  %{
                    "zoom" => 0.9528107916219694,
                    "value" => "🥳 новая лента \nс удобными фильтрами",
                    "center" => [243.12488824417846, 714.605913051134],
                    "position" => [120.62488824417846, 677.7725797178007],
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
                  "position" => [203.99061966150782, 441.45662306234],
                  "rotation" => 12.871057923604635,
                  "video_s3_key" => "3ff36b6e-6a25-4202-894f-17558ac95ffd"
                }
              },
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 1.0199362917254977,
                    "value" => "✨ новый чат",
                    "center" => [114.4461169082859, 156.52574165950466],
                    "position" => [35.27945024161923, 132.52574165950466],
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
                  "position" => [200.45700056424783, 433.80950891339785],
                  "rotation" => 17.634181896700753
                }
              },
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 1,
                    "value" => "✍️ сейчас можно написать \nинтересному человеку \nсразу",
                    "center" => [195.35060358255456, 178.21931853582547],
                    "position" => [48.51727024922121, 124.55265186915881],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "drawing" => %{
                  "lines" =>
                    "W3sicG9pbnRzIjpbWzIwOS42NjY2NTY0OTQxNDA2Miw3NzMuMzMzMzI4MjQ3MDcwMzFdLFsyMTEuNjY2NjU2NDk0MTQwNjIsNzY2LjMzMzMyODI0NzA3MDMxXSxbMjE1LjY2NjY1NjQ5NDE0MDYyLDc1OS42NjY2NTY0OTQxNDA2Ml0sWzIxOCw3NTYuNjY2NjU2NDk0MTQwNjJdLFsyMjAsNzUzLjMzMzMyODI0NzA3MDMxXSxbMjIzLjY2NjY1NjQ5NDE0MDYyLDc0N10sWzIyNy42NjY2NTY0OTQxNDA2Miw3NDAuMzMzMzI4MjQ3MDcwMzFdLFsyMzEuMzMzMzI4MjQ3MDcwMzEsNzMzLjMzMzMyODI0NzA3MDMxXSxbMjM0LjY2NjY1NjQ5NDE0MDYyLDcyNy4zMzMzMjgyNDcwNzAzMV0sWzIzOC4zMzMzMjgyNDcwNzAzMSw3MjEuMzMzMzI4MjQ3MDcwMzFdLFsyNDEuMzMzMzI4MjQ3MDcwMzEsNzE2XSxbMjQzLjMzMzMyODI0NzA3MDMxLDcxMl0sWzI0NSw3MDkuMzMzMzI4MjQ3MDcwMzFdLFsyNDUuNjY2NjU2NDk0MTQwNjIsNzA4LjMzMzMyODI0NzA3MDMxXSxbMjQ1LjY2NjY1NjQ5NDE0MDYyLDcwOF0sWzI0NS4zMzMzMjgyNDcwNzAzMSw3MDcuNjY2NjU2NDk0MTQwNjJdLFsyNDUsNzA3LjMzMzMyODI0NzA3MDMxXSxbMjQ0LjY2NjY1NjQ5NDE0MDYyLDcwN10sWzI0NC42NjY2NTY0OTQxNDA2Miw3MDYuNjY2NjU2NDk0MTQwNjJdLFsyNDQuMzMzMzI4MjQ3MDcwMzEsNzA2LjY2NjY1NjQ5NDE0MDYyXSxbMjQ0LDcwNi42NjY2NTY0OTQxNDA2Ml0sWzI0Mi42NjY2NTY0OTQxNDA2Miw3MDYuNjY2NjU2NDk0MTQwNjJdLFsyNDEsNzA3LjY2NjY1NjQ5NDE0MDYyXSxbMjM3LjY2NjY1NjQ5NDE0MDYyLDcxMV0sWzIzNCw3MTQuMzMzMzI4MjQ3MDcwMzFdLFsyMzEuMzMzMzI4MjQ3MDcwMzEsNzE3LjMzMzMyODI0NzA3MDMxXSxbMjI5LDcxOS4zMzMzMjgyNDcwNzAzMV0sWzIyNy42NjY2NTY0OTQxNDA2Miw3MjAuNjY2NjU2NDk0MTQwNjJdLFsyMjcuMzMzMzI4MjQ3MDcwMzEsNzIxLjMzMzMyODI0NzA3MDMxXSxbMjI3LjY2NjY1NjQ5NDE0MDYyLDcyMS4zMzMzMjgyNDcwNzAzMV0sWzIzMC42NjY2NTY0OTQxNDA2Miw3MTldLFsyMzQuMzMzMzI4MjQ3MDcwMzEsNzE1LjMzMzMyODI0NzA3MDMxXSxbMjM5LjMzMzMyODI0NzA3MDMxLDcxMS4zMzMzMjgyNDcwNzAzMV0sWzI0My4zMzMzMjgyNDcwNzAzMSw3MDcuNjY2NjU2NDk0MTQwNjJdLFsyNDYuNjY2NjU2NDk0MTQwNjIsNzA1XSxbMjQ5LDcwMy42NjY2NTY0OTQxNDA2Ml0sWzI0OS42NjY2NTY0OTQxNDA2Miw3MDMuNjY2NjU2NDk0MTQwNjJdLFsyNTAsNzAzLjY2NjY1NjQ5NDE0MDYyXSxbMjUwLDcwNS42NjY2NTY0OTQxNDA2Ml0sWzI1MCw3MTBdLFsyNTAsNzE2XSxbMjUwLDcyMy42NjY2NTY0OTQxNDA2Ml0sWzI1MSw3MzddXSwic3Ryb2tlX2NvbG9yIjoiIzExMTAxMCIsInN0cm9rZV93aWR0aCI6NX0seyJwb2ludHMiOltbMjg1LjMzMzMyODI0NzA3MDMxLDY0MC42NjY2NTY0OTQxNDA2Ml0sWzI3Nyw2MzQuMzMzMzI4MjQ3MDcwMzFdLFsyNzMsNjM0LjMzMzMyODI0NzA3MDMxXSxbMjY2LjMzMzMyODI0NzA3MDMxLDYzNS42NjY2NTY0OTQxNDA2Ml0sWzI1Ny42NjY2NTY0OTQxNDA2Miw2NDAuNjY2NjU2NDk0MTQwNjJdLFsyNDguMzMzMzI4MjQ3MDcwMzEsNjQ2LjY2NjY1NjQ5NDE0MDYyXSxbMjQxLDY1M10sWzIzNC4zMzMzMjgyNDcwNzAzMSw2NTkuMzMzMzI4MjQ3MDcwMzFdLFsyMzAuMzMzMzI4MjQ3MDcwMzEsNjY2LjY2NjY1NjQ5NDE0MDYyXSxbMjI4LDY3NF0sWzIyNy42NjY2NTY0OTQxNDA2Miw2ODEuMzMzMzI4MjQ3MDcwMzFdLFsyMjcuNjY2NjU2NDk0MTQwNjIsNjg4LjMzMzMyODI0NzA3MDMxXSxbMjMwLjY2NjY1NjQ5NDE0MDYyLDY5My42NjY2NTY0OTQxNDA2Ml0sWzIzNyw2OTddLFsyNDUuMzMzMzI4MjQ3MDcwMzEsNjk4LjMzMzMyODI0NzA3MDMxXSxbMjU0LjMzMzMyODI0NzA3MDMxLDY5OC4zMzMzMjgyNDcwNzAzMV0sWzI2My42NjY2NTY0OTQxNDA2Miw2OTguMzMzMzI4MjQ3MDcwMzFdLFsyNzMuMzMzMzI4MjQ3MDcwMzEsNjk1XSxbMjgyLjMzMzMyODI0NzA3MDMxLDY4OS42NjY2NTY0OTQxNDA2Ml0sWzI5MSw2ODIuNjY2NjU2NDk0MTQwNjJdLFsyOTgsNjc0LjY2NjY1NjQ5NDE0MDYyXSxbMzAzLDY2NS4zMzMzMjgyNDcwNzAzMV0sWzMwNC42NjY2NTY0OTQxNDA2Miw2NTVdLFszMDQuNjY2NjU2NDk0MTQwNjIsNjQ0LjY2NjY1NjQ5NDE0MDYyXSxbMzAwLjMzMzMyODI0NzA3MDMxLDYzNS4zMzMzMjgyNDcwNzAzMV0sWzI5MS4zMzMzMjgyNDcwNzAzMSw2MjhdLFsyODAuMzMzMzI4MjQ3MDcwMzEsNjI0LjMzMzMyODI0NzA3MDMxXSxbMjY3LjY2NjY1NjQ5NDE0MDYyLDYyNF0sWzI1Mi4zMzMzMjgyNDcwNzAzMSw2MjUuNjY2NjU2NDk0MTQwNjJdLFsyNDEuNjY2NjU2NDk0MTQwNjIsNjI5LjY2NjY1NjQ5NDE0MDYyXV0sInN0cm9rZV9jb2xvciI6IiNEMkQzREMiLCJzdHJva2Vfd2lkdGgiOjV9XQ=="
                },
                "background" => %{
                  "zoom" => 0.6489606347725142,
                  "color" => "#FF782D",
                  "s3_key" => "2d29c0c0-ccca-4984-9adc-36f416c2da92",
                  "position" => [68.45267621935973, 148.13861212599903],
                  "rotation" => 10.152636648541895
                }
              }
            ]
          },
          %{
            id: 18,
            timestamp: ~U[2022-11-06 14:00:00Z],
            version: "8.1.1",
            story: [
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 0.8633950233104907,
                    "value" => "Привет 👋 Попробуй новую \nфункцию — Встречи для \nофлайн общения",
                    "center" => [142.33333333333334, 154.66666666666666],
                    "position" => [14.550869883380727, 108.33113374900367],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 0,
                    "background_fill" => "#FFFFFF"
                  },
                  %{
                    "zoom" => 1,
                    "value" => "Попробовать ❤️‍🔥",
                    "action" => "open_meetings",
                    "center" => [195.09994548286605, 721.500010172526],
                    "position" => [101.26661214953272, 698.000010172526],
                    "rotation" => 0,
                    "alignment" => 1,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "background" => %{
                  "zoom" => 0.6500332858953728,
                  "color" => "#6D42B1",
                  "s3_key" => "46872d61-b739-40c0-990b-0f49cd619407",
                  "position" => [68.24350925040231, 147.6859533521527],
                  "rotation" => 9.786263824164644,
                  "video_s3_key" => "84d03c18-0d03-4ee1-ace9-128ddca06db1"
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
                    "center" => [147.78368109872378, 123.85998447159142],
                    "position" => [53.783681098723775, 85.19331780492476],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  },
                  %{
                    "zoom" => 1,
                    "value" => "🥳 new feed\n with handy filters",
                    "center" => [240.10772585669775, 721.7359742990652],
                    "position" => [141.27439252336444, 683.0693076323986],
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
                  "position" => [208.38128207048214, 450.95846683971],
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
                    "center" => [114.36762699495581, 139.57675713217668],
                    "position" => [42.20096032828914, 116.07675713217668],
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
                  "position" => [289.85999336479426, 627.2867548715035],
                  "rotation" => 13.038451156159331
                }
              },
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 1,
                    "value" => "✍️ now you can connect \nwith interesting person\n straightaway",
                    "center" => [159.62275192308286, 162.67664678289577],
                    "position" => [28.956085256416202, 109.00998011622912],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "drawing" => %{
                  "lines" =>
                    "W3sicG9pbnRzIjpbWzIxMC4zMzMzMjgyNDcwNzAzMSw3NjkuMzMzMzI4MjQ3MDcwMzFdLFsyMDkuMzMzMzI4MjQ3MDcwMzEsNzY3LjMzMzMyODI0NzA3MDMxXSxbMjE0LDc2MC42NjY2NTY0OTQxNDA2Ml0sWzIxOS4zMzMzMjgyNDcwNzAzMSw3NTIuNjY2NjU2NDk0MTQwNjJdLFsyMjQuMzMzMzI4MjQ3MDcwMzEsNzQzLjY2NjY1NjQ5NDE0MDYyXSxbMjI4LjY2NjY1NjQ5NDE0MDYyLDczNS4zMzMzMjgyNDcwNzAzMV0sWzIzMi4zMzMzMjgyNDcwNzAzMSw3MjguMzMzMzI4MjQ3MDcwMzFdLFsyMzYuMzMzMzI4MjQ3MDcwMzEsNzIyLjMzMzMyODI0NzA3MDMxXSxbMjM5LDcxNy42NjY2NTY0OTQxNDA2Ml0sWzI0MC42NjY2NTY0OTQxNDA2Miw3MTUuMzMzMzI4MjQ3MDcwMzFdLFsyNDEsNzE1LjMzMzMyODI0NzA3MDMxXSxbMjQxLDcxNS42NjY2NTY0OTQxNDA2Ml0sWzIzOS42NjY2NTY0OTQxNDA2Miw3MTcuNjY2NjU2NDk0MTQwNjJdLFsyMzYsNzIwXSxbMjMxLjY2NjY1NjQ5NDE0MDYyLDcyMi42NjY2NTY0OTQxNDA2Ml0sWzIyNyw3MjUuMzMzMzI4MjQ3MDcwMzFdLFsyMjIuNjY2NjU2NDk0MTQwNjIsNzI3LjY2NjY1NjQ5NDE0MDYyXSxbMjE5LDczMF0sWzIxNS42NjY2NTY0OTQxNDA2Miw3MzJdLFsyMTMuMzMzMzI4MjQ3MDcwMzEsNzM0XSxbMjEyLjMzMzMyODI0NzA3MDMxLDczNC42NjY2NTY0OTQxNDA2Ml0sWzIxMi4zMzMzMjgyNDcwNzAzMSw3MzVdLFsyMTMuMzMzMzI4MjQ3MDcwMzEsNzM1XSxbMjE3LjY2NjY1NjQ5NDE0MDYyLDczMS42NjY2NTY0OTQxNDA2Ml0sWzIyMi4zMzMzMjgyNDcwNzAzMSw3MjhdLFsyMjcuNjY2NjU2NDk0MTQwNjIsNzIzLjY2NjY1NjQ5NDE0MDYyXSxbMjMyLjY2NjY1NjQ5NDE0MDYyLDcyMC4zMzMzMjgyNDcwNzAzMV0sWzIzNyw3MTcuNjY2NjU2NDk0MTQwNjJdLFsyMzkuNjY2NjU2NDk0MTQwNjIsNzE3XSxbMjQwLjMzMzMyODI0NzA3MDMxLDcxN10sWzI0MC42NjY2NTY0OTQxNDA2Miw3MTkuMzMzMzI4MjQ3MDcwMzFdLFsyNDAuNjY2NjU2NDk0MTQwNjIsNzM0LjMzMzMyODI0NzA3MDMxXSxbMjQwLjY2NjY1NjQ5NDE0MDYyLDc0NS42NjY2NTY0OTQxNDA2Ml1dLCJzdHJva2VfY29sb3IiOiIjMTExMDEwIiwic3Ryb2tlX3dpZHRoIjo1fSx7InBvaW50cyI6W1syNzksNjcwLjY2NjY1NjQ5NDE0MDYyXSxbMjc2LDY2MC4zMzMzMjgyNDcwNzAzMV0sWzI3NC4zMzMzMjgyNDcwNzAzMSw2NTUuNjY2NjU2NDk0MTQwNjJdLFsyNzAsNjUxLjY2NjY1NjQ5NDE0MDYyXSxbMjY0LjY2NjY1NjQ5NDE0MDYyLDY0OC4zMzMzMjgyNDcwNzAzMV0sWzI1OSw2NDZdLFsyNTMsNjQ1XSxbMjQ3LDY0NV0sWzI0MC42NjY2NTY0OTQxNDA2Miw2NDZdLFsyMzQsNjUwLjY2NjY1NjQ5NDE0MDYyXSxbMjI3LjY2NjY1NjQ5NDE0MDYyLDY1Nl0sWzIyMiw2NjIuMzMzMzI4MjQ3MDcwMzFdLFsyMTcuNjY2NjU2NDk0MTQwNjIsNjY4LjY2NjY1NjQ5NDE0MDYyXSxbMjE0LjY2NjY1NjQ5NDE0MDYyLDY3NS4zMzMzMjgyNDcwNzAzMV0sWzIxMy42NjY2NTY0OTQxNDA2Miw2ODFdLFsyMTMuNjY2NjU2NDk0MTQwNjIsNjg3XSxbMjEzLjY2NjY1NjQ5NDE0MDYyLDY5M10sWzIxOCw2OTkuMzMzMzI4MjQ3MDcwMzFdLFsyMjQuNjY2NjU2NDk0MTQwNjIsNzA1LjMzMzMyODI0NzA3MDMxXSxbMjMzLDcwOS4zMzMzMjgyNDcwNzAzMV0sWzI0My4zMzMzMjgyNDcwNzAzMSw3MTAuNjY2NjU2NDk0MTQwNjJdLFsyNTcuMzMzMzI4MjQ3MDcwMzEsNzEwLjY2NjY1NjQ5NDE0MDYyXSxbMjc1LjMzMzMyODI0NzA3MDMxLDcwMy42NjY2NTY0OTQxNDA2Ml0sWzI5OS4zMzMzMjgyNDcwNzAzMSw2ODldXSwic3Ryb2tlX2NvbG9yIjoiI0QyRDNEQyIsInN0cm9rZV93aWR0aCI6NX1d"
                },
                "background" => %{
                  "zoom" => 0.6566673314695014,
                  "color" => "#FF782D",
                  "s3_key" => "7e9dd14d-dab3-4182-bbb4-e11dbe51244c",
                  "position" => [66.94987036344722, 144.8863861198704],
                  "rotation" => 13.335573158989895
                }
              }
            ]
          },
          %{
            id: 18,
            timestamp: ~U[2022-11-06 14:00:00Z],
            version: "8.1.1",
            story: [
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 1.1090914151064903,
                    "value" => "Try ❤️‍🔥",
                    "action" => "open_meetings",
                    "center" => [195, 726.1666666666666],
                    "position" => [146.09277663280426, 700.0201126357427],
                    "rotation" => 0,
                    "alignment" => 1,
                    "text_color" => "#111010",
                    "corner_radius" => 1,
                    "background_fill" => "#FFFFFF"
                  },
                  %{
                    "zoom" => 0.9353689153331752,
                    "value" => "Hey 👋 Try a new feature:\nMeetings to meet offline",
                    "center" => [142, 156.33333333333334],
                    "position" => [15.725196430021342, 120.1657352737839],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 0,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "background" => %{
                  "zoom" => 0.6539308412568758,
                  "color" => "#6D42B1",
                  "s3_key" => "4dee4875-fcbb-4958-88d2-bb133c3f02cc",
                  "position" => [67.48348595490921, 146.04118498959838],
                  "rotation" => 10.439117091329278,
                  "video_s3_key" => "bb085367-b597-46c8-85f0-9a1d8f1de4ad"
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
