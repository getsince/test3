defmodule T.Todos do
  @moduledoc false
  import Ecto.Query
  import T.Gettext

  alias T.{Repo, Accounts}

  defp todos do
    [
      %{
        story: [
          %{
            "background" => %{"color" => "#111010"},
            "labels" => [
              %{
                "value" => dgettext("news", "В твоей истории\nне хватает контакта"),
                "position" => [24.0, 80.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "value" => dgettext("news", "Добавь его на приватную страницу"),
                "position" => [24.0, 148.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "value" => dgettext("news", "Жми 👇"),
                "position" => [24.0, 423.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "action" => "add_contact",
                "value" => dgettext("news", "Добавить контакт"),
                "position" => [150.0, 513.0]
              }
            ],
            "size" => [375, 667]
          }
        ]
      }
    ]
  end

  @spec list_todos(Ecto.Bigflake.UUID.t()) :: [%{story: [map]}]
  def list_todos(user_id) do
    if has_contact?(user_id) do
      []
    else
      todos()
    end
  end

  defp has_contact?(user_id) do
    Accounts.Profile
    |> where(user_id: ^user_id)
    |> select([p], p.story)
    |> Repo.one()
    |> then(fn story -> story || [] end)
    |> Enum.any?(fn page ->
      Enum.any?(page["labels"] || [], fn label ->
        label["question"] in Accounts.Profile.contacts()
      end)
    end)
  end
end
