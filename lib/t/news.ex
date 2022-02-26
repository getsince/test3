defmodule T.News do
  @moduledoc false
  import Ecto.Query
  import T.Gettext

  alias T.Repo
  alias T.News.SeenNews

  defp news do
    [
      %{
        id: 1,
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
                "url" => "https://t.me/getsince",
                "question" => "telegram",
                "rotation" => 20
              },
              %{
                "position" => [160.0, 339.0],
                "answer" => "getsince.app",
                "url" => "https://www.instagram.com/getsince.app",
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
  end

  defp last_id do
    List.last(news()).id
  end

  @spec list_news(Ecto.Bigflake.UUID.t()) :: [%{id: pos_integer(), story: [map]}]
  def list_news(user_id) do
    last_seen_id = last_seen_id(user_id) || 0
    Enum.filter(news(), fn news_story -> news_story.id > last_seen_id end)
  end

  def mark_seen(user_id, news_story_id \\ last_id()) do
    Repo.transaction(fn ->
      last_seen_id = last_seen_id(user_id) || 0

      if last_seen_id < news_story_id do
        Repo.insert_all(SeenNews, [%{user_id: user_id, last_id: news_story_id}])
      end
    end)
  end

  @spec last_seen_id(Ecto.Bigflake.UUID.t()) :: pos_integer() | nil
  defp last_seen_id(user_id) do
    SeenNews |> where(user_id: ^user_id) |> select([n], n.last_id) |> Repo.one()
  end
end
