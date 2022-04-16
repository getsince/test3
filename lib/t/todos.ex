defmodule T.Todos do
  @moduledoc false
  import Ecto.Query
  import T.Gettext

  alias T.{Repo, Accounts}

  defp update_app_todo do
    %{
      story: [
        %{
          "background" => %{"color" => "#111010"},
          "labels" => [
            %{
              "value" =>
                dgettext("todos", "Твоя версия приложения\nне поддерживает\nновые функции 📟"),
              "position" => [24.0, 230.0],
              "background_fill" => "#F97EB9"
            },
            %{
              "action" => "update_app",
              "value" => dgettext("todos", "Обновить"),
              "position" => [24.0, 352.0],
              "background_fill" => "#F97EB9"
            }
          ],
          "size" => [375, 667]
        }
      ]
    }
  end

  defp contact_todo do
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
  end

  @spec list_todos(Ecto.Bigflake.UUID.t(), Version.t()) :: [%{story: [map]}]
  def list_todos(user_id, version) do
    todos =
      if has_contact?(user_id) do
        []
      else
        [contact_todo()]
      end

    case Version.compare(version, last_minor_version_update()) do
      :lt -> [update_app_todo() | todos]
      _ -> todos
    end
  end

  defp last_minor_version_update, do: "6.2.0"

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
