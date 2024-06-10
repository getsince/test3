defmodule Since.Todos do
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

  defp hidden_profile_todo do
    case Gettext.get_locale() do
      "ru" ->
        %{
          story: [
            %{
              "size" => [428, 926],
              "labels" => [
                %{
                  "zoom" => 1.0,
                  "value" => "Внимание ⚠️\nТвой профиль не показывается \nдругим пользователям",
                  "center" => [213.69953548158213, 283.9573384195964],
                  "position" => [62.36620214824879, 235.79067175292974],
                  "rotation" => 0,
                  "alignment" => 1,
                  "text_color" => "#111010",
                  "corner_radius" => 1,
                  "background_fill" => "#FFFFFF"
                },
                %{
                  "zoom" => 1.0,
                  "value" => "Добавь свои фото и\nрасскажи о себе\n🙏",
                  "center" => [214.33333333333331, 433],
                  "position" => [116.33333333333331, 385.3333333333333],
                  "rotation" => 0,
                  "alignment" => 1,
                  "text_color" => "#111010",
                  "corner_radius" => 1,
                  "background_fill" => "#FFFFFF"
                },
                %{
                  "zoom" => 1.5,
                  "value" => "👇👇👇",
                  "center" => [214, 548.3333435058595],
                  "position" => [140, 511.0000101725262],
                  "rotation" => 0,
                  "alignment" => 1,
                  "text_color" => "#FFFFFF",
                  "corner_radius" => 1,
                  "background_fill" => "#111010"
                },
                %{
                  "zoom" => 1.0,
                  "action" => "edit_story",
                  "value" => "Редактировать профиль",
                  "center" => [214.15215706080198, 653.6666717529297],
                  "position" => [100.65215706080198, 633.5000050862631],
                  "rotation" => 0,
                  "alignment" => 1,
                  "text_color" => "#111010",
                  "corner_radius" => 1,
                  "background_fill" => "#FFFFFF"
                }
              ],
              "background" => %{"color" => "#111010"}
            }
          ]
        }

      _ ->
        %{
          story: [
            %{
              "size" => [428, 926],
              "labels" => [
                %{
                  "zoom" => 1,
                  "value" => "Attention ⚠️ \nYour profile is not shown\nto other users",
                  "center" => [214.01033333333334, 244.33332316080728],
                  "position" => [71.67699999999999, 185.66665649414062],
                  "rotation" => 0,
                  "alignment" => 1,
                  "text_color" => "#111010",
                  "corner_radius" => 1,
                  "background_fill" => "#FFFFFF"
                },
                %{
                  "zoom" => 1,
                  "value" => "Please add photos\nand tell about yourself\n🙏",
                  "center" => [214.33333333333331, 423],
                  "position" => [82.49999999999997, 364.3333333333333],
                  "rotation" => 0,
                  "alignment" => 1,
                  "text_color" => "#111010",
                  "corner_radius" => 1,
                  "background_fill" => "#FFFFFF"
                },
                %{
                  "zoom" => 1.5,
                  "value" => "👇👇👇",
                  "center" => [214.14845383167255, 573.499994913737],
                  "position" => [140.31512049833924, 536.6666615804037],
                  "rotation" => 0,
                  "alignment" => 0,
                  "text_color" => "#FFFFFF",
                  "corner_radius" => 1,
                  "background_fill" => "#111010"
                },
                %{
                  "zoom" => 1,
                  "action" => "edit_story",
                  "value" => "Edit profile",
                  "center" => [214.16666666666669, 683.6666666666666],
                  "position" => [141.33333333333337, 658],
                  "rotation" => 0,
                  "alignment" => 1,
                  "text_color" => "#111010",
                  "corner_radius" => 1,
                  "background_fill" => "#FFFFFF"
                }
              ],
              "background" => %{"color" => "#111010"}
            }
          ]
        }
    end
  end

  @spec list_todos(Ecto.Bigflake.UUID.t(), Version.t(), boolean) :: [%{story: [map]}]
  def list_todos(_user_id, version, hidden?) do
    maybe_update_todo =
      case Version.compare(version, last_minor_version_update()) do
        :lt -> [update_app_todo()]
        _ -> []
      end

    maybe_hidden_todo =
      case hidden? do
        true -> [hidden_profile_todo()]
        false -> []
      end

    maybe_hidden_todo ++ maybe_update_todo
  end

  defp last_minor_version_update, do: "8.3.0"
end
