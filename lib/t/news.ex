defmodule T.News do
  @moduledoc false
  import Ecto.Query
  import T.Gettext

  alias T.Repo
  alias T.News.SeenNews

  @news [
    %{
      id: 1,
      story: [
        %{
          "background" => %{"color" => "#F97EB9"},
          "labels" => [
            %{
              "value" => dgettext("news", "Привет! 👋"),
              "position" => [24.0, 180.0]
            },
            %{
              "value" => dgettext("news", "Это Since -\nпространство для\nинтересных людей."),
              "position" => [24.0, 248.0]
            },
            %{
              "value" => dgettext("news", "Обновления 👉"),
              "position" => [150.0, 500.0]
            }
          ],
          "size" => [375, 667]
        },
        %{
          "background" => %{"color" => "#F97EB9"},
          "labels" => [
            %{
              "value" => dgettext("news", "Стикеры-контакты 🔥"),
              "position" => [24.0, 180.0]
            },
            %{
              "value" => dgettext("news", "Добавляй контакты\nв свою Историю."),
              "position" => [24.0, 248.0]
            },
            %{
              "value" => dgettext("news", "Нажми 👇"),
              "position" => [125.0, 374.0]
            },
            %{
              "position" => [50.0, 510.0],
              "value" => "getsince",
              "answer" => "https://t.me/getsince",
              "question" => "telegram",
              "rotation" => 20
            },
            %{
              "position" => [160.0, 445.0],
              "value" => "getsince.app",
              "answer" => "https://www.instagram.com/getsince.app",
              "question" => "instagram",
              "rotation" => -17
            }
          ],
          "size" => [375, 667]
        },
        %{
          "background" => %{"color" => "#F97EB9"},
          "labels" => [
            %{
              "value" =>
                dgettext(
                  "news",
                  "Теперь стикеры-контакты -\nединственный способ\nкоммуникации."
                ),
              "position" => [24.0, 200.0]
            },
            %{
              "value" => dgettext("news", "Общайся с мэтчами,\nгде тебе удобно."),
              "position" => [24.0, 319.0]
            },
            %{
              "value" =>
                dgettext(
                  "news",
                  "Это ещё не всё 👉"
                ),
              "position" => [150.0, 500.0]
            }
          ],
          "size" => [375, 667]
        },
        %{
          "background" => %{"color" => "#F97EB9"},
          "labels" => [
            %{
              "value" => dgettext("news", "Приватная страница 👀"),
              "position" => [24.0, 131.0]
            },
            %{
              "value" =>
                dgettext(
                  "news",
                  "Создай приватную страницу,\nона будет видна только\nтвоим мэтчам."
                ),
              "position" => [24.0, 200.0]
            },
            %{
              "value" =>
                dgettext(
                  "news",
                  "На нее можно поместить\nсвой контакт и что-то\nболее личное про тебя."
                ),
              "position" => [24.0, 322.0]
            },
            %{
              "value" =>
                dgettext(
                  "news",
                  "Выглядит вот так 👉"
                ),
              "position" => [130.0, 500.0]
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

  @last_id List.last(@news).id

  @spec list_news(Ecto.Bigflake.UUID.t()) :: [%{id: pos_integer(), story: [map]}]
  def list_news(user_id) do
    last_seen_id = last_seen_id(user_id) || 0
    Enum.filter(@news, fn news_story -> news_story.id > last_seen_id end)
  end

  def mark_seen(user_id, news_story_id \\ @last_id) do
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
