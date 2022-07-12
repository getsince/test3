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
          },
          %{
            id: 15,
            timestamp: ~U[2022-06-27 17:00:00Z],
            version: "7.0.1",
            story: [
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 0.8977998910358647,
                    "value" =>
                      "Привет 👋 В этом апдейте: \n\n• Фотостикеры в нашем \nновом чате 🥳  Попробуйте \nподелиться своими фото \nс мэтчем в новом режиме!",
                    "position" => [17.175305093383827, 94.32840021792822],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#FFFFFF",
                    "corner_radius" => 0,
                    "background_fill" => "#FE7760"
                  }
                ],
                "background" => %{
                  "zoom" => 1.0136904675816325,
                  "color" => "#5C443B",
                  "s3_key" => "cb44b620-6231-4fad-ac10-6f67dee646fc",
                  "position" => [-2.6696411784183454, -5.777377319448931],
                  "rotation" => 0
                }
              },
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 1,
                    "value" => "• Новый выбор \nмузыкального трека 👀",
                    "position" => [10.000000000000028, 170.33333333333334],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#FFFFFF",
                    "corner_radius" => 1,
                    "background_fill" => "#FE7760"
                  }
                ],
                "background" => %{
                  "zoom" => 1,
                  "color" => "#B78A81",
                  "s3_key" => "60d0a4fd-abfd-41ba-a9fc-585bf994c443",
                  "position" => [0, 0],
                  "rotation" => 0
                }
              }
            ]
          }
        ]

      _ ->
        [
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
          },
          %{
            id: 15,
            timestamp: ~U[2022-06-27 17:00:00Z],
            version: "7.0.1",
            story: [
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 0.9181634582418595,
                    "value" =>
                      "Hey 👋 In this update:\n\n• Photo stickers in our new \nchat 🥳  Try to share your \nphotos in a new way!",
                    "position" => [9.965899868131203, 83.96953658166471],
                    "rotation" => 0.000000000000000021118111604764806,
                    "alignment" => 0,
                    "text_color" => "#FFFFFF",
                    "corner_radius" => 0,
                    "background_fill" => "#FE7760"
                  }
                ],
                "background" => %{
                  "zoom" => 1.0275840532757667,
                  "color" => "#5C443B",
                  "s3_key" => "dd04652f-d162-43d1-9f7f-c7d3377e954c",
                  "position" => [-5.378890388774522, -11.640470482373587],
                  "rotation" => 0
                }
              },
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 1,
                    "value" => "• Updated music track \nselection  👀",
                    "position" => [20.74560055177851, 164.66667683919272],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#FFFFFF",
                    "corner_radius" => 1,
                    "background_fill" => "#FE7760"
                  }
                ],
                "background" => %{
                  "zoom" => 1,
                  "color" => "#B78A81",
                  "s3_key" => "07dc05e1-3161-4039-a6c5-e6312919c5fe",
                  "position" => [0, 0],
                  "rotation" => 0
                }
              }
            ]
          }
        ]
    end
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
