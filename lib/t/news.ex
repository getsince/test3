defmodule T.News do
  @moduledoc false
  import Ecto.Query
  import T.Gettext

  alias T.Repo
  alias T.News.SeenNews

  import T.Cluster, only: [primary_rpc: 3]

  defp news do
    pivot_news = [
      %{
        id: 1,
        timestamp: ~U[2022-03-02 20:31:00Z],
        version: "6.0.0",
        story: [
          %{
            "background" => %{"color" => "#111010"},
            "labels" => [
              %{
                "value" => dgettext("news", "Привет! 👋"),
                "position" => [24.0, 80.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "value" => dgettext("news", "У нас важные новости."),
                "position" => [24.0, 148.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "value" => dgettext("news", "Мы убрали аудио-дэйты\nи голосовые сообщения."),
                "position" => [24.0, 216.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "value" =>
                  dgettext("news", "Теперь контакты -\nединственный способ\nкоммуникации."),
                "position" => [24.0, 306.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "value" => dgettext("news", "Общайся с мэтчами,\nгде тебе удобно."),
                "position" => [24.0, 423.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "value" => dgettext("news", "Подробности 👉"),
                "position" => [150.0, 513.0],
                "background_fill" => "#F97EB9"
              }
            ],
            "size" => [375, 667]
          },
          %{
            "background" => %{"color" => "#F97EB9"},
            "labels" => [
              %{
                "value" => dgettext("news", "Представляем\nстикеры-контакты 🔥"),
                "position" => [24.0, 80.0]
              },
              %{
                "value" => dgettext("news", "Добавляй контакты\nв свою историю."),
                "position" => [24.0, 178.0]
              },
              %{
                "value" => dgettext("news", "Вот наши, нажми 👇"),
                "position" => [74.0, 268.0]
              },
              %{
                "position" => [50.0, 404.0],
                "answer" => "getsince",
                "question" => "telegram",
                "rotation" => 20
              },
              %{
                "position" => [160.0, 339.0],
                "answer" => "getsince.app",
                "question" => "instagram",
                "rotation" => -17
              },
              %{
                "value" => dgettext("news", "Это ещё не всё 👉"),
                "position" => [150.0, 513.0]
              }
            ],
            "size" => [375, 667]
          },
          %{
            "background" => %{"color" => "#111010"},
            "labels" => [
              %{
                "value" => dgettext("news", "Новые\nприватные страницы 👀"),
                "position" => [24.0, 109.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "value" =>
                  dgettext(
                    "news",
                    "Создай приватную страницу,\nона будет видна только\nтвоим мэтчам."
                  ),
                "position" => [24.0, 200.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "value" =>
                  dgettext(
                    "news",
                    "На нее можно поместить\nсвой контакт и что-то\nболее личное про тебя."
                  ),
                "position" => [24.0, 322.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "value" => dgettext("news", "Выглядит вот так 👉"),
                "position" => [130.0, 500.0],
                "background_fill" => "#F97EB9"
              }
            ],
            "size" => [375, 667]
          },
          %{
            "blurred" => %{
              "s3_key" => "5cfbe96c-e456-43bb-8d3a-98e849c00d5d"
            }
          },
          %{
            "background" => %{"color" => "#F97EB9"},
            "labels" => [
              %{
                "value" => dgettext("news", "Попробуй новый Since ✨"),
                "position" => [24.0, 310.0]
              }
            ],
            "size" => [375, 667]
          }
        ]
      }
    ]

    other_news =
      case Gettext.get_locale() do
        "ru" ->
          [
            %{
              id: 4,
              timestamp: ~U[2022-04-09 12:00:00Z],
              version: "6.1.2",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1.0156433551059274,
                      "value" => "У нас новый апдейт:",
                      "position" => [11.818352957901183, 144.11386740238515],
                      "rotation" => -0.000000000000000012232681543189033,
                      "alignment" => 0,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 0.9361257037749625,
                      "value" => "• Ресайз фотографий 👇",
                      "position" => [11.793239287788808, 201.00106122007756],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    }
                  ],
                  "background" => %{
                    "zoom" => 1.1315270791341807,
                    "color" => "#6B4D32",
                    "s3_key" => "28295fd5-eb78-4e87-97c7-61b857bb5f24",
                    "position" => [-205.18224344932196, -444.03541915699407],
                    "rotation" => 0
                  }
                },
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1,
                      "value" => "этичный образ жизни",
                      "answer" => "этичный образ жизни",
                      "position" => [58.66666666666666, 364.124],
                      "question" => "worldview",
                      "rotation" => 0
                    },
                    %{
                      "zoom" => 1,
                      "value" => "slow living",
                      "answer" => "slow living",
                      "position" => [114, 481.3333231608073],
                      "question" => "worldview",
                      "rotation" => 0
                    },
                    %{
                      "zoom" => 1,
                      "value" => "гедонизм",
                      "answer" => "гедонизм",
                      "position" => [115.66666666666667, 424.3333282470703],
                      "question" => "worldview",
                      "rotation" => 0
                    },
                    %{
                      "zoom" => 1,
                      "value" => "оптимистическое",
                      "answer" => "оптимистическое",
                      "position" => [76, 537.6666666666667],
                      "question" => "worldview",
                      "rotation" => 0
                    },
                    %{
                      "zoom" => 1,
                      "value" => "• добавили новую \nкатегорию стикеров — \nмировоззрение 🌎",
                      "position" => [68.16666666666669, 221.33331807454428],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    }
                  ],
                  "background" => %{"color" => "#5E50FC"}
                },
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 0.8227475861552165,
                      "value" => "• новый редактор текста ✍️",
                      "position" => [23.262899318002084, 141.54110603171702],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 0.8160309784078537,
                      "value" => "• сетка в редакторе 👇",
                      "position" => [150.2414146415445, 210.82327200741543],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "action" => "edit_story",
                      "value" => "ПОПРОБОВАТЬ",
                      "position" => [106.33333333333331, 697.5],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    }
                  ],
                  "background" => %{
                    "zoom" => 1.1458749645399164,
                    "color" => "#2A261E",
                    "s3_key" => "b318c953-6fc2-4d21-aeba-53b1c64ff931",
                    "position" => [-199.11932659698599, -430.91464525091305],
                    "rotation" => 0
                  }
                },
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1,
                      "answer" => "getsince",
                      "position" => [119.16666666666667, 418.1666819254557],
                      "question" => "telegram",
                      "rotation" => 0
                    },
                    %{
                      "zoom" => 1,
                      "value" => "Ждём вашего фидбэка \nздесь 👇",
                      "position" => [68.66667175292969, 324.6666615804037],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    }
                  ],
                  "background" => %{"color" => "#F97EB9"}
                }
              ]
            }
          ]

        _ ->
          [
            %{
              id: 4,
              timestamp: ~U[2022-04-09 12:00:00Z],
              version: "6.1.2",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1,
                      "value" => "• resize photos 👇",
                      "position" => [11.833333333333314, 195.8333282470703],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1.0877015758127484,
                      "value" => "It’s a new update!",
                      "position" => [11.999989827473968, 133.8963513879968],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    }
                  ],
                  "background" => %{
                    "zoom" => 1.134265138646841,
                    "color" => "#6B4D32",
                    "s3_key" => "a3985666-6cd1-4bf5-8929-ec33f71fc299",
                    "position" => [-157.090212216804, -339.9593310538014],
                    "rotation" => 0
                  }
                },
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1,
                      "value" => "• added new category of \nstickers: worldview 🌎",
                      "position" => [61.66666666666663, 239.33333333333334],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "value" => "slow living",
                      "answer" => "slow living",
                      "position" => [114, 347.3333282470703],
                      "question" => "worldview",
                      "rotation" => 0
                    },
                    %{
                      "zoom" => 1,
                      "value" => "optimistic",
                      "answer" => "optimistic",
                      "position" => [115, 407.6666717529297],
                      "question" => "worldview",
                      "rotation" => 0
                    },
                    %{
                      "zoom" => 1,
                      "value" => "ethical lifestyle",
                      "answer" => "ethical lifestyle",
                      "position" => [90.5, 465.999994913737],
                      "question" => "worldview",
                      "rotation" => 0
                    },
                    %{
                      "zoom" => 1,
                      "value" => "hedonism",
                      "answer" => "hedonism",
                      "position" => [115.66666666666667, 526.6666666666666],
                      "question" => "worldview",
                      "rotation" => 0
                    }
                  ],
                  "background" => %{"color" => "#5E50FC"}
                },
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1,
                      "value" => "• new text editor ✍️",
                      "position" => [20.33334859212256, 129.9573384195963],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "value" => "• layout grids 👇",
                      "position" => [156.6666564941405, 197.83334350585938],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "action" => "edit_story",
                      "value" => "TRY",
                      "position" => [161.0000050862629, 701.1666717529297],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    }
                  ],
                  "background" => %{
                    "zoom" => 1.187483248072997,
                    "color" => "#2A261E",
                    "s3_key" => "b0b1e4eb-b342-4092-a17f-48301784a01b",
                    "position" => [-219.35540024540654, -474.7075841208285],
                    "rotation" => 0
                  }
                },
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1,
                      "answer" => "getsince",
                      "position" => [119.16666158040361, 406.6666717529297],
                      "question" => "telegram",
                      "rotation" => 0
                    },
                    %{
                      "zoom" => 1,
                      "value" => "Waiting for your feedback \nhere 👇",
                      "position" => [57.33332824707023, 310.33333333333337],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    }
                  ],
                  "background" => %{"color" => "#F97EB9"}
                }
              ]
            }
          ]
      end

    pivot_news ++ other_news
  end

  defp last_id do
    List.last(news()).id
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
