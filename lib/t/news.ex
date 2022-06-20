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
            },
            %{
              id: 5,
              timestamp: ~U[2022-04-17 10:00:00Z],
              version: "6.2.0",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1.457105408422635,
                      "s3_key" => "6173e9c3-b6ae-4509-a272-b6d603d2b23f",
                      "duration" => 9.91764172335601,
                      "position" => [68.4744178219179, 353.3155172684568],
                      "question" => "audio",
                      "rotation" => 0,
                      "waveform" =>
                        "AAAAAFKkkHEYOkbGVZhpTA1Q5lwHJbWUMqmkldglbCGkFP0MnVUSK4OEEUIgzUFZmjvtuQOVWyqpNAIIAYQA",
                      "icon_color" => "#111010",
                      "background_color" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "value" => "ПРИВЕТ, ЭТО КЛАССНОЕ \nОБНОВЛЕНИЕ ✨",
                      "position" => [59, 191.99998982747397],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "action" => "add_voice_sticker",
                      "zoom" => 1,
                      "value" => "ПОПРОБОВАТЬ",
                      "position" => [106.33333333333331, 659.7709461331171],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "value" => "ПОПРОБУЙ НОВЫЕ \nГОЛОСОВЫЕ СТИКЕРЫ \nИ ДОБАВЬ ИХ В ПРОФИЛЬ \n🎙",
                      "position" => [55.1666615804036, 488.0000050862629],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    }
                  ],
                  "background" => %{"color" => "#F97EB9"}
                }
              ]
            },
            %{
              id: 6,
              timestamp: ~U[2022-04-23 10:00:00Z],
              version: "6.2.1",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "action" => "add_spotify_sticker",
                      "zoom" => 1,
                      "value" => "ПОПРОБОВАТЬ",
                      "position" => [106.5, 672.1042642076615],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "value" => "ПРИВЕТ, ЭТО НОВЫЙ \nАПДЕЙТ 🎵",
                      "position" => [77.33333333333333, 128.33333333333334],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "value" =>
                        "МУЗЫКАЛЬНЫЕ СТИКЕРЫ \n— ДОБАВЛЯЙ СВОИ \nЛЮБИМЫЕ ТРЕКИ \nВ ПРОФИЛЬ",
                      "position" => [52.83333333333337, 221.16668192545575],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "id" => "6MowG7MRVgPfGlCMsXKMJ2",
                      "name" => "Bird Set Free",
                      "zoom" => 1.2880375414542946,
                      "image" =>
                        "https://i.scdn.co/image/ab67616d0000b273754b2fddebe7039fdb912837",
                      "artist" => "Sia",
                      "preview" =>
                        "https://p.scdn.co/mp3-preview/1c33af1033d742b3a11e1ee64a31038aab708683?cid=bb46df9e00484884abf679b374964d43",
                      "spotify" => "https://open.spotify.com/track/6MowG7MRVgPfGlCMsXKMJ2",
                      "position" => [58.516026862753876, 436.0599892685336],
                      "question" => "spotify",
                      "rotation" => -10.823884344665968,
                      "background_color" => "#FFFFFF"
                    }
                  ],
                  "background" => %{"color" => "#F97EB9"}
                }
              ]
            },
            %{
              id: 7,
              timestamp: ~U[2022-05-01 10:00:00Z],
              version: "6.3.0",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 0.7900495540705151,
                      "value" => "ПРИВЕТ, ЭТО НОВЫЙ \nАПДЕЙТ 📹",
                      "position" => [102.03750247103605, 28.79068192545573],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 0.7691950904818243,
                      "value" => "ТЕПЕРЬ МОЖНО ДОБАВИТЬ \nВИДЕО В СВОЙ ПРОФИЛЬ",
                      "position" => [80.90272824519602, 96.59111808177315],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "action" => "pick_background",
                      "zoom" => 1,
                      "value" => "ПОПРОБОВАТЬ",
                      "position" => [106.33333333333331, 727.3127977092473],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    }
                  ],
                  "background" => %{
                    "zoom" => 0.6882104232606352,
                    "color" => "#D0F85F",
                    "s3_key" => "50197722-a674-4bf0-a96a-f9108de097a7",
                    "position" => [60.798967464176144, 131.57520138401196],
                    "rotation" => -0.04575294846351457,
                    "video_s3_key" => "3ee97c73-5869-413d-a8f3-871af488c87e"
                  }
                }
              ]
            },
            %{
              id: 8,
              timestamp: ~U[2022-05-10 22:00:00Z],
              version: "6.3.2",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1,
                      "action" => "add_video_sticker",
                      "value" => "ПОПРОБОВАТЬ",
                      "position" => [106.37444825329857, 659.5],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "value" => "НОВЫЙ АПДЕЙТ: ВИДЕО-\nСТИКЕРЫ ✨",
                      "position" => [59.83424939948725, 149.6666463216146],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1.4884624543018328,
                      "s3_key" => "a786c371-b346-4d1f-a032-4d7ee35a2217",
                      "duration" => 1.6,
                      "position" => [92.85716214058026, 383.715866692624],
                      "question" => "video",
                      "rotation" => 0,
                      "video_s3_key" => "c9674b14-d5de-4e64-963f-d2b578397af1"
                    },
                    %{
                      "zoom" => 1,
                      "value" => "ПОПРОБУЙ И ДОБАВЬ \nВ СВОЙ ПРОФИЛЬ👇",
                      "position" => [72.39217465079425, 247.00000508626303],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    }
                  ],
                  "background" => %{"color" => "#5E50FC"}
                }
              ]
            },
            %{
              id: 9,
              timestamp: ~U[2022-05-10 22:00:00Z],
              version: "6.3.2",
              story: [
                %{
                  "size" => [428, 926],
                  "labels" => [],
                  "background" => %{
                    "zoom" => 1,
                    "color" => "#B2688C",
                    "s3_key" => "69ad75a3-fcb6-4d7c-96fb-9b0c33e913ad",
                    "position" => [0, 0],
                    "rotation" => 0,
                    "video_s3_key" => "1c517358-7691-4c91-8778-81eac664231b"
                  }
                }
              ]
            },
            %{
              id: 10,
              timestamp: ~U[2022-05-15 18:00:00Z],
              version: "6.3.3",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 0.9817104354487304,
                      "value" =>
                        "У НАС НОВОСТИ: МЫ \nОБНОВИЛИ ЛЭЙАУТ \nИ ДОБАВИЛИ ЛОКАЦИЮ \nВ ИСТОРИИ",
                      "position" => [63.76156683115224, 88.61791246243587],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "value" => "👆",
                      "position" => [63.464621936855806, 698.97480240297],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "action" => "view_own_profile",
                      "value" => "МОЙ ПРОФИЛЬ",
                      "position" => [143.464621936855806, 698.97480240297],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    }
                  ],
                  "background" => %{
                    "zoom" => 0.6459271262799298,
                    "color" => "#646260",
                    "s3_key" => "f93996b9-df1e-4f8a-85a3-ec6fd34779b4",
                    "position" => [207.13263112624105, 448.2562581296089],
                    "rotation" => 0
                  }
                },
                %{
                  "size" => [428, 926],
                  "labels" => [],
                  "background" => %{
                    "zoom" => 1,
                    "color" => "#000000",
                    "s3_key" => "f1db77db-8173-4459-a5c8-3ee46f003682",
                    "position" => [0, 0],
                    "rotation" => 0,
                    "video_s3_key" => "b3058393-738e-49b9-a796-ce1764e29757"
                  }
                }
              ]
            },
            %{
              id: 11,
              timestamp: ~U[2022-05-23 19:00:00Z],
              version: "6.3.4",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [],
                  "background" => %{
                    "zoom" => 1,
                    "color" => "#000000",
                    "s3_key" => "8c1523f3-c1e8-4fbe-a5f0-b7ea3de20594",
                    "position" => [0, 0],
                    "rotation" => 0,
                    "video_s3_key" => "45dab9e9-046f-4e42-8f5c-c5125ad53e35"
                  }
                }
              ]
            },
            %{
              id: 12,
              timestamp: ~U[2022-05-30 00:00:00Z],
              version: "6.3.5",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [],
                  "background" => %{
                    "zoom" => 1,
                    "color" => "#000000",
                    "s3_key" => "913e19f6-e0b6-457a-83b0-f15ae1b4b375",
                    "position" => [0, 0],
                    "rotation" => 0,
                    "video_s3_key" => "447ad6f3-1c15-4e99-855b-8480db08e5f3"
                  }
                }
              ]
            },
            %{
              id: 13,
              timestamp: ~U[2022-06-06 00:00:00Z],
              version: "6.3.6",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [],
                  "background" => %{
                    "zoom" => 1,
                    "color" => "#000000",
                    "s3_key" => "bd54d02f-a7f5-4c77-95bf-577da3b1b277",
                    "position" => [0, 0],
                    "rotation" => 0,
                    "video_s3_key" => "bf37544a-41d8-46ce-8ef5-1562caeb54a6"
                  }
                }
              ]
            },
            %{
              id: 14,
              timestamp: ~U[2022-06-20 15:00:00Z],
              version: "7.0.0",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1.0812157246656098,
                      "value" => "Перелистывай истории \nв ленте с помощью тапа ✨",
                      "position" => [38.14852564901551, 380.1806040902553],
                      "rotation" => 0,
                      "alignment" => 0,
                      "text_color" => "#FFFFFF",
                      "corner_radius" => 0,
                      "background_fill" => "#49BDB5"
                    },
                    %{
                      "zoom" => 1.0987303955681236,
                      "value" => "Привет! Это новый \nклассный апдейт 🥳",
                      "position" => [38.64531142113411, 271.8490633969193],
                      "rotation" => -0.00000000000000035810350722516816,
                      "alignment" => 0,
                      "text_color" => "#FFFFFF",
                      "corner_radius" => 0,
                      "background_fill" => "#49BDB5"
                    },
                    %{
                      "zoom" => 1.4972990066668805,
                      "value" => "👉👉👉",
                      "position" => [30.465989802747984, 469.64680159039864],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#FFFFFF",
                      "corner_radius" => 1,
                      "background_fill" => "#49BDB5"
                    }
                  ],
                  "background" => %{"color" => "#49BDB5"}
                },
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 0.9485222716761664,
                      "value" =>
                        "Новая навигация и меню: \nперемещайся между \nмэтчами, своим профилем \nи лентой с помощью \nсвайпа 👇",
                      "position" => [19.631320479591352, 227.4821780775087],
                      "rotation" => 0,
                      "alignment" => 0,
                      "text_color" => "#FFFFFF",
                      "corner_radius" => 0,
                      "background_fill" => "#5F5DAE"
                    },
                    %{
                      "zoom" => 1.4977121395875672,
                      "value" => "😍😍😍",
                      "position" => [120.85984412806306, 541.1371082255515],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#FFFFFF",
                      "corner_radius" => 1,
                      "background_fill" => "#5F5DAE"
                    }
                  ],
                  "background" => %{
                    "zoom" => 1,
                    "color" => "#5F5DAE",
                    "s3_key" => "8f7f2005-cafd-4b1d-b332-b4f37b5af7ac",
                    "position" => [0, 0],
                    "rotation" => 0
                  }
                },
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 0.8237025697440704,
                      "value" =>
                        "И на десерт: теперь ты \nможешь общаться со \nсвоими мэтчами прямо \nв приложении 🤤",
                      "position" => [15.074231765088683, 78.23749460803225],
                      "rotation" => 0,
                      "alignment" => 0,
                      "text_color" => "#FFFFFF",
                      "corner_radius" => 0,
                      "background_fill" => "#ED3D90"
                    },
                    %{
                      "zoom" => 1.4898863139654077,
                      "value" => "🍒🍒🍒",
                      "position" => [245.1057095085913, 148.8210151276723],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#FFFFFF",
                      "corner_radius" => 1,
                      "background_fill" => "#ED3D90"
                    },
                    %{
                      "zoom" => 0.8406568001204867,
                      "value" =>
                        "Делайте это креативно \nи свободно, создавайте \nвместе общий холст 🧚‍♀️",
                      "position" => [9.842383519760205, 646.051423479797],
                      "rotation" => 0,
                      "alignment" => 0,
                      "text_color" => "#FFFFFF",
                      "corner_radius" => 0,
                      "background_fill" => "#ED3D90"
                    }
                  ],
                  "background" => %{
                    "zoom" => 0.50020345634647,
                    "color" => "#ED3D90",
                    "s3_key" => "2e26a82b-12c6-4e79-80bd-429dba391f2b",
                    "position" => [97.46032601243834, 210.91414142178965],
                    "rotation" => 11.15822197434413,
                    "video_s3_key" => "1a0d39a0-df6a-4f26-8c4d-3ea4212273f1"
                  }
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
            },
            %{
              id: 5,
              timestamp: ~U[2022-04-17 10:00:00Z],
              version: "6.2.0",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1,
                      "value" => "TRY & ADD NEW VOICE\nSTICKERS TO YOUR PROFILE \n🎙",
                      "position" => [47.5, 527.0000050862631],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "action" => "add_voice_sticker",
                      "zoom" => 1,
                      "value" => "TRY",
                      "position" => [155.1666615804036, 662.4376077135208],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "value" => "HEY, IT’S A COOL UPDATE!",
                      "position" => [60.33333333333334, 184.5],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1.4161878705011162,
                      "s3_key" => "1832dd14-a795-460b-acb2-75dd0421cedd",
                      "duration" => 7.473945578231293,
                      "position" => [72.02059935551983, 347.77512939180696],
                      "question" => "audio",
                      "rotation" => 0,
                      "waveform" =>
                        "AAAAABg0vujEQo01hhpDSAwxQgDRWa42xtS1Rqk6Vs0nGWHme/hurq059OJj6tVII5GyrNtKcyaIEEIIIYQA",
                      "icon_color" => "#111010",
                      "background_color" => "#FFFFFF"
                    }
                  ],
                  "background" => %{"color" => "#F97EB9"}
                }
              ]
            },
            %{
              id: 6,
              timestamp: ~U[2022-04-23 10:00:00Z],
              version: "6.2.1",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1,
                      "value" => "NEW UPDATE 🎵",
                      "position" => [103.8333435058592, 147.49998474121094],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "value" => "TRY MUSIC STICKERS AND \nADD YOUR FAVOURITE \nMUSIC TRACKS",
                      "position" => [55.16666666666666, 211.00000508626303],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "action" => "add_spotify_sticker",
                      "zoom" => 1,
                      "value" => "TRY",
                      "position" => [161.16666666666666, 680.5],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "id" => "6MowG7MRVgPfGlCMsXKMJ2",
                      "name" => "Bird Set Free",
                      "zoom" => 1.3601382489707192,
                      "image" =>
                        "https://i.scdn.co/image/ab67616d0000b273754b2fddebe7039fdb912837",
                      "artist" => "Sia",
                      "preview" =>
                        "https://p.scdn.co/mp3-preview/1c33af1033d742b3a11e1ee64a31038aab708683?cid=bb46df9e00484884abf679b374964d43",
                      "spotify" => "https://open.spotify.com/track/6MowG7MRVgPfGlCMsXKMJ2",
                      "position" => [50.885368650598934, 437.0191935944803],
                      "question" => "spotify",
                      "rotation" => -11.373607793676973,
                      "background_color" => "#FFFFFF"
                    }
                  ],
                  "background" => %{"color" => "#F97EB9"}
                }
              ]
            },
            %{
              id: 7,
              timestamp: ~U[2022-05-01 10:00:00Z],
              version: "6.3.0",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "action" => "pick_background",
                      "zoom" => 1,
                      "value" => "TRY",
                      "position" => [160.99999999999997, 700.8333282470703],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "value" => "NEW UPDATE 📹",
                      "position" => [103.8333435058592, 28.95731807454428],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 0.8795544139202892,
                      "value" => "NOW YOU CAN ADD A VIDEO \nTO YOUR PROFILE",
                      "position" => [65.81195011360731, 82.65721915588944],
                      "rotation" => 0.0000000000000004520122108317562,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    }
                  ],
                  "background" => %{
                    "zoom" => 0.6394023869722604,
                    "color" => "#D0F85F",
                    "s3_key" => "437edee1-f4a3-4175-b854-45a2b17d7a4b",
                    "position" => [70.31653454040922, 152.17219269770612],
                    "rotation" => -0.1767680149137344,
                    "video_s3_key" => "9781d5a7-653c-45a0-84bc-eab48f8e8d93"
                  }
                }
              ]
            },
            %{
              id: 8,
              timestamp: ~U[2022-05-10 22:00:00Z],
              version: "6.3.2",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1,
                      "value" => "NEW UPDATE: VIDEO \nSTICKERS ✨",
                      "position" => [82.07597805605457, 149.66667683919272],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "action" => "add_video_sticker",
                      "value" => "TRY",
                      "position" => [161.26061894440966, 658.1414639833736],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 1,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "value" => "TRY AND ADD TO YOUR \nPROFILE 👇",
                      "position" => [71.49872149667277, 242.66666158040366],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1.4968963309343162,
                      "s3_key" => "9cdc2947-dbe0-458b-8a1b-726ae634b645",
                      "duration" => 1.5316666666666667,
                      "position" => [92.27943650499229, 375.3048051805708],
                      "question" => "video",
                      "rotation" => 0,
                      "video_s3_key" => "028059bf-9703-40ab-ac0f-4e431832f203"
                    }
                  ],
                  "background" => %{"color" => "#5E50FC"}
                }
              ]
            },
            %{
              id: 9,
              timestamp: ~U[2022-05-10 22:00:00Z],
              version: "6.3.2",
              story: [
                %{
                  "size" => [428, 926],
                  "labels" => [],
                  "background" => %{
                    "zoom" => 1,
                    "color" => "#B1698C",
                    "s3_key" => "f640677c-9a5a-4a30-b095-85ed7d111171",
                    "position" => [0, 0],
                    "rotation" => 0,
                    "video_s3_key" => "f958297d-9b59-49a1-9286-eaaae4884305"
                  }
                }
              ]
            },
            %{
              id: 10,
              timestamp: ~U[2022-05-15 18:00:00Z],
              version: "6.3.3",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1,
                      "value" => "SOME NEWS: NEW LAYOUT \nAND LOCATION IN THE \nPROFILE ",
                      "position" => [53.00552941671188, 114.08133841959636],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "value" => "👆",
                      "position" => [58.163362965788295, 714.5],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    },
                    %{
                      "zoom" => 1,
                      "action" => "view_own_profile",
                      "value" => "MY PROFILE",
                      "position" => [138.163362965788295, 714.5],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#111010",
                      "corner_radius" => 0,
                      "background_fill" => "#FFFFFF"
                    }
                  ],
                  "background" => %{
                    "zoom" => 0.6891007091647834,
                    "color" => "#64625F",
                    "s3_key" => "d9e74b98-3d83-4272-b4ac-acecaa801ab9",
                    "position" => [60.62536171286723, 131.1995007324614],
                    "rotation" => 0
                  }
                },
                %{
                  "size" => [428, 926],
                  "labels" => [],
                  "background" => %{
                    "zoom" => 1,
                    "color" => "#000000",
                    "s3_key" => "b25cb723-0a19-4e56-9095-cb8c0204bfca",
                    "position" => [0, 0],
                    "rotation" => 0,
                    "video_s3_key" => "f0ecbff5-e5f6-47b2-be32-8ca2263326b4"
                  }
                }
              ]
            },
            %{
              id: 11,
              timestamp: ~U[2022-05-23 19:00:00Z],
              version: "6.3.4",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [],
                  "background" => %{
                    "zoom" => 1,
                    "color" => "#000000",
                    "s3_key" => "b3e84b9c-7dfb-4d78-967c-93e4a49e12d1",
                    "position" => [0, 0],
                    "rotation" => 0,
                    "video_s3_key" => "3c736ec2-a61a-4543-a1ab-bebc0ce55e51"
                  }
                }
              ]
            },
            %{
              id: 12,
              timestamp: ~U[2022-05-30 00:00:00Z],
              version: "6.3.5",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [],
                  "background" => %{
                    "zoom" => 1,
                    "color" => "#000000",
                    "s3_key" => "a46819d4-940b-4baa-842e-0eec02a7b746",
                    "position" => [0, 0],
                    "rotation" => 0,
                    "video_s3_key" => "4025cf0d-8863-46a5-ac7a-a26fff194e56"
                  }
                }
              ]
            },
            %{
              id: 13,
              timestamp: ~U[2022-06-06 00:00:00Z],
              version: "6.3.6",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [],
                  "background" => %{
                    "zoom" => 1,
                    "color" => "#000000",
                    "s3_key" => "54c66190-47da-48b3-8a5d-e84569ecdb7c",
                    "position" => [0, 0],
                    "rotation" => 0,
                    "video_s3_key" => "f0f408b8-9d0d-4d07-86cc-6d7074cba7c6"
                  }
                }
              ]
            },
            %{
              id: 14,
              timestamp: ~U[2022-06-20 15:00:00Z],
              version: "7.0.0",
              story: [
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1.122901464489404,
                      "value" => "👀\nUse tap to navigate between\npages in feed ✨",
                      "position" => [31.827809420050784, 331.4042855292705],
                      "rotation" => 0,
                      "alignment" => 0,
                      "text_color" => "#FFFFFF",
                      "corner_radius" => 1,
                      "background_fill" => "#49BDB5"
                    },
                    %{
                      "zoom" => 1.2139971013916773,
                      "value" => "Hey! It’s the coolest \nupdate 🥳",
                      "position" => [27.98991657618899, 216.7254504991182],
                      "rotation" => 0,
                      "alignment" => 0,
                      "text_color" => "#FFFFFF",
                      "corner_radius" => 1,
                      "background_fill" => "#49BDB5"
                    }
                  ],
                  "background" => %{"color" => "#49BDB5"}
                },
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 1,
                      "value" =>
                        "New navigation & menu: \nnavigate between matches, \nyour profile, and feed \nwith a swipe 👇",
                      "position" => [28.707509156149115, 310.99998982747394],
                      "rotation" => 0,
                      "alignment" => 0,
                      "text_color" => "#FFFFFF",
                      "corner_radius" => 1,
                      "background_fill" => "#5F5DAE"
                    },
                    %{
                      "zoom" => 1.4945521250066083,
                      "value" => "😍😍😍",
                      "position" => [19.491721440141504, 556.0446891858799],
                      "rotation" => 0,
                      "alignment" => 1,
                      "text_color" => "#FFFFFF",
                      "corner_radius" => 1,
                      "background_fill" => "#5F5DAE"
                    }
                  ],
                  "background" => %{
                    "zoom" => 0.8422531778339764,
                    "color" => "#5F5DAE",
                    "s3_key" => "93cec1c6-590d-466c-b233-48371c22de3e",
                    "position" => [30.760630322374624, 66.569158954062],
                    "rotation" => 0
                  }
                },
                %{
                  "size" => [390, 844],
                  "labels" => [
                    %{
                      "zoom" => 0.7771570124471355,
                      "value" =>
                        "🍒🍒🍒\nAnd the most delicious part: \nnow you can chat with you match\nright in the app\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nBe creative & make your \ncommon canvas 🧚‍♀️",
                      "position" => [10, 74.12400000000008],
                      "rotation" => 0,
                      "alignment" => 0,
                      "text_color" => "#FFFFFF",
                      "corner_radius" => 1,
                      "background_fill" => "#ED3D90"
                    }
                  ],
                  "background" => %{
                    "zoom" => 0.5015777747655887,
                    "color" => "#ED3D90",
                    "s3_key" => "2b402c22-919f-4e50-9797-1fd80854abbb",
                    "position" => [97.1923339207102, 210.33417904892156],
                    "rotation" => 6.608296500916767,
                    "video_s3_key" => "d8857711-08cf-4291-9df1-5d9af2aacf69"
                  }
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
