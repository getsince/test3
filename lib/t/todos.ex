defmodule T.Todos do
  @moduledoc false
  import T.Gettext

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

  @spec list_todos(Ecto.Bigflake.UUID.t(), Version.t()) :: [%{story: [map]}]
  def list_todos(_user_id, version) do
    case Version.compare(version, last_minor_version_update()) do
      :lt -> [update_app_todo()]
      _ -> []
    end
  end

  defp last_minor_version_update, do: "7.1.0"
end
