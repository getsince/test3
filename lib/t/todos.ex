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
                "value" => dgettext("todos", "В твоей истории\nне хватает контакта"),
                "position" => [24.0, 150.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "value" => dgettext("todos", "Без него твои мэтчи\nне смогут связаться с тобой"),
                "position" => [24.0, 240.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "value" => dgettext("todos", "Жми 👇"),
                "position" => [24.0, 330.0],
                "background_fill" => "#F97EB9"
              },
              %{
                "action" => "add_contact",
                "value" => dgettext("todos", "Добавить контакт"),
                "position" => [24.0, 500.0]
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
