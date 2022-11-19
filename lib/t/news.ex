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
            id: 19,
            timestamp: ~U[2022-10-18 14:00:00Z],
            version: "8.2.0",
            story: [
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 0.7109998249431089,
                    "value" =>
                      "Привет 👋 Попробуй игру-опрос: выбирай людей, \nотвечая на вопросы и узнавай, кому интересен ты",
                    "center" => [193.33333333333334, 117.83333333333331],
                    "position" => [7.812537712879987, 88.87513807785646],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 0,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "drawing" => %{
                  "lines" =>
                    "W3sicG9pbnRzIjpbWzEyLDI0OV0sWzMxLDIzNy4zMzMzMjgyNDcwNzAzMV0sWzMxLDIzNy4zMzMzMjgyNDcwNzAzMV0sWzM3LjY2NjY1NjQ5NDE0MDYyNSwyMzIuMzMzMzI4MjQ3MDcwMzFdLFs0NC4zMzMzMjgyNDcwNzAzMTIsMjI3XSxbNTEuMzMzMzI4MjQ3MDcwMzEyLDIyMi42NjY2NTY0OTQxNDA2Ml0sWzU3LjMzMzMyODI0NzA3MDMxMiwyMThdLFs2My42NjY2NTY0OTQxNDA2MjUsMjE0LjMzMzMyODI0NzA3MDMxXSxbNjkuMzMzMzI4MjQ3MDcwMzEyLDIwOS42NjY2NTY0OTQxNDA2Ml0sWzc0LjY2NjY1NjQ5NDE0MDYyNSwyMDZdLFs3OS4zMzMzMjgyNDcwNzAzMTIsMjAxLjY2NjY1NjQ5NDE0MDYyXSxbODMuNjY2NjU2NDk0MTQwNjI1LDE5Ny42NjY2NTY0OTQxNDA2Ml0sWzg3LjMzMzMyODI0NzA3MDMxMiwxOTRdLFs5MS4zMzMzMjgyNDcwNzAzMTIsMTkwLjMzMzMyODI0NzA3MDMxXSxbOTQuNjY2NjU2NDk0MTQwNjI1LDE4Ny42NjY2NTY0OTQxNDA2Ml0sWzk4LDE4NC42NjY2NTY0OTQxNDA2Ml0sWzEwMC4zMzMzMjgyNDcwNzAzMSwxODNdLFsxMDIsMTgxLjY2NjY1NjQ5NDE0MDYyXSxbMTAzLDE4MS4zMzMzMjgyNDcwNzAzMV0sWzEwMy4zMzMzMjgyNDcwNzAzMSwxODEuMzMzMzI4MjQ3MDcwMzFdLFsxMDIsMTgxLjMzMzMyODI0NzA3MDMxXSxbMTAwLjMzMzMyODI0NzA3MDMxLDE4MS4zMzMzMjgyNDcwNzAzMV0sWzk4LDE4MS4zMzMzMjgyNDcwNzAzMV0sWzk0LjY2NjY1NjQ5NDE0MDYyNSwxODEuMzMzMzI4MjQ3MDcwMzFdLFs5MC42NjY2NTY0OTQxNDA2MjUsMTgxLjMzMzMyODI0NzA3MDMxXSxbODUuMzMzMzI4MjQ3MDcwMzEyLDE4MS42NjY2NTY0OTQxNDA2Ml0sWzgxLjMzMzMyODI0NzA3MDMxMiwxODIuNjY2NjU2NDk0MTQwNjJdLFs3Ny42NjY2NTY0OTQxNDA2MjUsMTg0XSxbNzQuMzMzMzI4MjQ3MDcwMzEyLDE4NV0sWzcyLDE4NS42NjY2NTY0OTQxNDA2Ml0sWzY5LjY2NjY1NjQ5NDE0MDYyNSwxODYuMzMzMzI4MjQ3MDcwMzFdLFs2OC42NjY2NTY0OTQxNDA2MjUsMTg2LjY2NjY1NjQ5NDE0MDYyXSxbNjguNjY2NjU2NDk0MTQwNjI1LDE4N10sWzcyLDE4N10sWzc2LjY2NjY1NjQ5NDE0MDYyNSwxODddLFs4MS42NjY2NTY0OTQxNDA2MjUsMTg3XSxbODYuNjY2NjU2NDk0MTQwNjI1LDE4N10sWzkyLDE4N10sWzk1LjY2NjY1NjQ5NDE0MDYyNSwxODYuMzMzMzI4MjQ3MDcwMzFdLFs5OC42NjY2NTY0OTQxNDA2MjUsMTg1LjY2NjY1NjQ5NDE0MDYyXSxbMTAwLjY2NjY1NjQ5NDE0MDYyLDE4NS4zMzMzMjgyNDcwNzAzMV0sWzEwMS4zMzMzMjgyNDcwNzAzMSwxODUuMzMzMzI4MjQ3MDcwMzFdLFsxMDEuNjY2NjU2NDk0MTQwNjIsMTg1LjMzMzMyODI0NzA3MDMxXSxbMTAxLjY2NjY1NjQ5NDE0MDYyLDE4NS42NjY2NTY0OTQxNDA2Ml0sWzEwMS42NjY2NTY0OTQxNDA2MiwxOTAuMzMzMzI4MjQ3MDcwMzFdLFs5OSwyMDFdLFs5MywyMTkuNjY2NjU2NDk0MTQwNjJdXSwic3Ryb2tlX2NvbG9yIjoiIzExMTAxMCIsInN0cm9rZV93aWR0aCI6NX1d"
                },
                "background" => %{
                  "zoom" => 0.6507977927920133,
                  "color" => "#83E36B",
                  "s3_key" => "6d80b83a-475b-434f-b640-1a21da608610",
                  "position" => [68.0944304055574, 147.36333144177036],
                  "rotation" => 5.822303900740022,
                  "video_s3_key" => "85bd2da6-2cd2-4273-87d3-d52823ac90a8"
                }
              }
            ]
          }
        ]

      _ ->
        [
          %{
            id: 19,
            timestamp: ~U[2022-10-18 14:00:00Z],
            version: "8.2.0",
            story: [
              %{
                "size" => [390, 844],
                "labels" => [
                  %{
                    "zoom" => 0.7846421379262476,
                    "value" =>
                      "Hey 👋 Try a new Survey Game: answer \nquestions & find out who is interested in you",
                    "center" => [183.14779241758373, 113.26084697434098],
                    "position" => [7.281515622027229, 82.1156976008658],
                    "rotation" => 0,
                    "alignment" => 0,
                    "text_color" => "#111010",
                    "corner_radius" => 0,
                    "background_fill" => "#FFFFFF"
                  }
                ],
                "drawing" => %{
                  "lines" =>
                    "W3sicG9pbnRzIjpbWzQ0LjMzMzMyODI0NzA3MDMxMiwyMjguNjY2NjU2NDk0MTQwNjJdLFs0OS4zMzMzMjgyNDcwNzAzMTIsMjI1XSxbNTQuNjY2NjU2NDk0MTQwNjI1LDIyMl0sWzYxLjMzMzMyODI0NzA3MDMxMiwyMTguMzMzMzI4MjQ3MDcwMzFdLFs2OC4zMzMzMjgyNDcwNzAzMTIsMjE1XSxbNzQuNjY2NjU2NDk0MTQwNjI1LDIxMS42NjY2NTY0OTQxNDA2Ml0sWzgxLjMzMzMyODI0NzA3MDMxMiwyMDhdLFs4OCwyMDQuMzMzMzI4MjQ3MDcwMzFdLFs5NC42NjY2NTY0OTQxNDA2MjUsMjAwLjMzMzMyODI0NzA3MDMxXSxbMTAxLDE5Ny4zMzMzMjgyNDcwNzAzMV0sWzEwNiwxOTQuNjY2NjU2NDk0MTQwNjJdLFsxMTAuMzMzMzI4MjQ3MDcwMzEsMTkyLjMzMzMyODI0NzA3MDMxXSxbMTEzLjY2NjY1NjQ5NDE0MDYyLDE5MC4zMzMzMjgyNDcwNzAzMV0sWzExNS4zMzMzMjgyNDcwNzAzMSwxODkuMzMzMzI4MjQ3MDcwMzFdLFsxMTYsMTg4LjY2NjY1NjQ5NDE0MDYyXSxbMTE1LjMzMzMyODI0NzA3MDMxLDE4OC42NjY2NTY0OTQxNDA2Ml0sWzExNC4zMzMzMjgyNDcwNzAzMSwxODguNjY2NjU2NDk0MTQwNjJdLFsxMTMuNjY2NjU2NDk0MTQwNjIsMTg4LjY2NjY1NjQ5NDE0MDYyXSxbMTEyLDE4OC42NjY2NTY0OTQxNDA2Ml0sWzExMCwxODkuMzMzMzI4MjQ3MDcwMzFdLFsxMDcuMzMzMzI4MjQ3MDcwMzEsMTkwXSxbMTA0LDE5MC4zMzMzMjgyNDcwNzAzMV0sWzEwMC42NjY2NTY0OTQxNDA2MiwxOTFdLFs5NywxOTEuNjY2NjU2NDk0MTQwNjJdLFs5NC4zMzMzMjgyNDcwNzAzMTIsMTkyLjMzMzMyODI0NzA3MDMxXSxbOTMsMTkyLjY2NjY1NjQ5NDE0MDYyXSxbOTIuNjY2NjU2NDk0MTQwNjI1LDE5Mi42NjY2NTY0OTQxNDA2Ml0sWzk0LDE5Mi42NjY2NTY0OTQxNDA2Ml0sWzk4LjY2NjY1NjQ5NDE0MDYyNSwxOTEuMzMzMzI4MjQ3MDcwMzFdLFsxMDQsMTg5LjMzMzMyODI0NzA3MDMxXSxbMTEwLDE4OF0sWzExNC4zMzMzMjgyNDcwNzAzMSwxODddLFsxMTcuNjY2NjU2NDk0MTQwNjIsMTg3XSxbMTE5LjMzMzMyODI0NzA3MDMxLDE4N10sWzExOS4zMzMzMjgyNDcwNzAzMSwxODcuNjY2NjU2NDk0MTQwNjJdLFsxMTgsMTkxLjMzMzMyODI0NzA3MDMxXSxbMTEzLjY2NjY1NjQ5NDE0MDYyLDE5OC42NjY2NTY0OTQxNDA2Ml0sWzEwNi4zMzMzMjgyNDcwNzAzMSwyMTFdLFs5OSwyMjZdXSwic3Ryb2tlX2NvbG9yIjoiIzExMTAxMCIsInN0cm9rZV93aWR0aCI6NX1d"
                },
                "background" => %{
                  "zoom" => 0.6502722213809004,
                  "color" => "#83E36B",
                  "s3_key" => "ac737044-6c0e-450f-85ed-61c3a6621354",
                  "position" => [68.19691683072443, 147.58512257726005],
                  "rotation" => 14.802944301601595,
                  "video_s3_key" => "11ccfa03-1536-4113-9902-c601e7c19ca4"
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
