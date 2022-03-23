defmodule T.News do
  @moduledoc false
  import Ecto.Query
  import T.Gettext

  alias T.Repo
  alias T.News.SeenNews

  import T.Cluster, only: [primary_rpc: 3]

  defp news do
    [
      %{
        id: 1,
        timestamp: DateTime.new!(~D[2022-03-02], ~T[20:31:00.000], "Etc/UTC"),
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
      },
      %{
        id: 2,
        timestamp: DateTime.new!(~D[2022-03-23], ~T[08:16:00.000], "Etc/UTC"),
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
                "value" => dgettext("news", "Мы добавили\nавтоматическую локацию."),
                "position" => [24.0, 148.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "value" =>
                  dgettext(
                    "news",
                    "Теперь в ленте показывается\nпримерное расстояние\nдо пользователя."
                  ),
                "position" => [24.0, 238.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "value" =>
                  dgettext(
                    "news",
                    "Ты можешь включить\nавтоматическое определение\nлокации, чтобы она\nоставалась актуальной 👇"
                  ),
                "position" => [24.0, 356.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "action" => "enable_auto_location",
                "value" => dgettext("news", "Включить авто-локацию"),
                "position" => [75.0, 502.0],
                "background_fill" => "#F97EB9"
              }
            ],
            "size" => [375, 667]
          }
        ]
      }
    ]
  end

  defp last_id do
    List.last(news()).id
  end

  @spec list_news(Ecto.Bigflake.UUID.t()) :: [%{id: pos_integer(), story: [map]}]
  def list_news(user_id) do
    last_seen_id = last_seen_id(user_id) || 0

    Enum.filter(news(), fn news_story -> news_story.id > last_seen_id end)
    |> Enum.filter(fn news_story ->
      case DateTime.compare(news_story.timestamp, user_inserted_at(user_id)) do
        :lt -> false
        _ -> true
      end
    end)
  end

  def mark_seen(user_id, news_story_id \\ last_id()) do
    primary_rpc(__MODULE__, :local_mark_seen, [user_id, news_story_id])
  end

  @doc false
  def local_mark_seen(user_id, news_story_id) do
    Repo.transaction(fn ->
      last_seen_id = last_seen_id(user_id)

      case last_seen_id do
        nil ->
          Repo.insert_all(SeenNews, [%{user_id: user_id, last_id: news_story_id}])

        last_seen_id when last_seen_id < news_story_id ->
          SeenNews |> where(user_id: ^user_id) |> Repo.update_all(set: [last_id: news_story_id])
      end
    end)
  end

  @spec last_seen_id(Ecto.Bigflake.UUID.t()) :: pos_integer() | nil
  defp last_seen_id(user_id) do
    SeenNews |> where(user_id: ^user_id) |> select([n], n.last_id) |> Repo.one()
  end

  defp user_inserted_at(user_id) do
    T.Accounts.User
    |> where(id: ^user_id)
    |> select([u], u.inserted_at)
    |> Repo.one!()
    |> DateTime.from_naive!("Etc/UTC")
  end
end
