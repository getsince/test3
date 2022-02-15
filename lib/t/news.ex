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
              "size" => [247.3, 44],
              "value" => dgettext("news", "Мы стали совсем другими"),
              "center" => [142.33, 317.83]
            }
          ],
          "size" => [428, 926]
        }
      ]
    }
  ]

  @last_id List.last(@news).id

  @spec list_news(Ecto.Bigflake.UUID.t()) :: [map]
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
