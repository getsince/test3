defmodule TWeb.ViewHelpersTest do
  use TWeb.ConnCase, async: true
  alias TWeb.ViewHelpers

  setup do
    story = [
      %{
        "background" => %{"s3_key" => "bg1.jpg"},
        "labels" => [
          # would be rendered in v5.2.3 and removed in v6.0.0
          %{"value" => "Пиши мне сразу в тг: @putin", "text-contact" => true},
          # text contact above has been manually replaced with a contact sticker
          # they would be rendered in v6.0.0 and removed in v5.2.3
          %{"question" => "telegram", "answer" => "putin"},
          %{"question" => "whatsapp", "answer" => "79169752435"},
          %{"question" => "instagram", "answer" => "putin"},
          %{"question" => "email", "answer" => "putin@hotmail.com"}
        ],
        "size" => [428, 926]
      },
      %{
        "background" => %{"s3_key" => "bg1.jpg"},
        "labels" => [
          %{"value" => "Или позвони: +79169752435", "text-contact" => true},
          %{"question" => "phone", "answer" => "+79169752435"}
        ],
        "size" => [428, 926]
      },
      # private stories are rendered in v6.0.0 and removed in v5.2.3
      %{
        "background" => %{"s3_key" => "naked.jpg"},
        "labels" => [],
        "blurred" => %{"s3_key" => "naked-blurred.jpg"},
        "size" => [428, 926]
      }
    ]

    {:ok, story: story}
  end

  test "v6.0.0", %{story: story} do
    assert [
             %{
               "background" => %{
                 "s3_key" => "bg1.jpg",
                 "proxy" => "https://d1234.cloudfront.net" <> _
               },
               "labels" => [
                 # note that "Пиши мне сразу в тг: @putin" has been removed
                 %{
                   "answer" => "putin",
                   "question" => "telegram",
                   "value" => "https://t.me/putin"
                 },
                 %{
                   "answer" => "79169752435",
                   "question" => "whatsapp",
                   "value" => "https://wa.me/79169752435"
                 },
                 %{
                   "answer" => "putin",
                   "question" => "instagram",
                   "value" => "https://instagram.com/putin"
                 },
                 %{"answer" => "putin@hotmail.com", "question" => "email"}
               ],
               "size" => [428, 926]
             },
             %{
               "background" => %{
                 "s3_key" => "bg1.jpg",
                 "proxy" => "https://d1234.cloudfront.net" <> _
               },
               "labels" => [%{"answer" => "+79169752435", "question" => "phone"}],
               "size" => [428, 926]
             },
             %{
               "blurred" => %{
                 "s3_key" => "naked-blurred.jpg",
                 "proxy" => "https://d1234.cloudfront.net" <> _
               },
               "private" => true
             }
           ] =
             ViewHelpers.postprocess_story(
               story,
               _version = "6.0.0",
               _screen_width = 1200,
               _env = :feed
             )
  end

  test "v5.2.3", %{story: story} do
    assert [
             %{
               "background" => %{
                 "s3_key" => "bg1.jpg",
                 "proxy" => "https://d1234.cloudfront.net" <> _
               },
               "labels" => [
                 %{"value" => "Пиши мне сразу в тг: @putin"}
                 # note that contacts have been removed
               ],
               "size" => [428, 926]
             },
             %{
               "background" => %{
                 "s3_key" => "bg1.jpg",
                 "proxy" => "https://d1234.cloudfront.net" <> _
               },
               "labels" => [%{"value" => "Или позвони: +79169752435"}],
               "size" => [428, 926]
             }
           ] =
             ViewHelpers.postprocess_story(
               story,
               _version = "5.2.3",
               _screen_width = 1200,
               _env = :feed
             )
  end
end
