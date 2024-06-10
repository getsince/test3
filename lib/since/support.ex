defmodule Since.Support do
  @moduledoc false

  def story do
    case Gettext.get_locale() do
      "ru" ->
        [
          %{
            "size" => [390, 844],
            "labels" => [
              %{
                "zoom" => 1.1036710391976081,
                "value" => "Поддержка, отзывы \nи предложения 👇",
                "center" => [194.90368228258376, 278.1666590372721],
                "position" => [70.37280002645365, 235.49137885496458],
                "rotation" => 0,
                "alignment" => 1,
                "text_color" => "#111010",
                "corner_radius" => 1,
                "background_fill" => "#FFFFFF"
              },
              %{
                "zoom" => 1.1750697887116828,
                "answer" => "getsince",
                "center" => [194.82804976202272, 410.99913159659303],
                "position" => [106.16138309535604, 383.49913159659303],
                "question" => "telegram",
                "rotation" => -0.0000000000000003536588944762358
              },
              %{
                "zoom" => 1.1322445528426317,
                "answer" => "support@getsince.app",
                "center" => [194.72837394423763, 477.5907147523995],
                "position" => [23.061707277570974, 451.0907147523995],
                "question" => "email",
                "rotation" => 0
              }
            ],
            "background" => %{"color" => "#85e26a"}
          }
        ]

      _ ->
        [
          %{
            "size" => [390, 844],
            "labels" => [
              %{
                "zoom" => 1.1349867923457626,
                "answer" => "getsinceapp",
                "center" => [194.859875706943, 408.5443827642043],
                "position" => [87.41445936487747, 381.6830286786879],
                "question" => "messenger",
                "rotation" => 0
              },
              %{
                "zoom" => 1.1877496838569641,
                "value" => "Support, feedback and \nsuggestions 👇",
                "center" => [195.01115715942882, 301],
                "position" => [48.34449049276216, 255.5],
                "rotation" => 0,
                "alignment" => 1,
                "text_color" => "#111010",
                "corner_radius" => 1,
                "background_fill" => "#FFFFFF"
              },
              %{
                "zoom" => 1.153968547422431,
                "answer" => "getsince",
                "center" => [194.85990113825812, 478.2110697759229],
                "position" => [85.61754531560132, 450.90048082025874],
                "question" => "telegram",
                "rotation" => 0
              },
              %{
                "zoom" => 1.0904446305588138,
                "answer" => "support@getsince.app",
                "center" => [194.74453728208618, 552.7110367152133],
                "position" => [29.17869420890628, 526.9038471253214],
                "question" => "email",
                "rotation" => -0.0000000000000003670865283153256
              }
            ],
            "background" => %{"color" => "#85e26a"}
          }
        ]
    end
  end
end
