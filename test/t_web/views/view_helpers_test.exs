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
          %{"question" => "email", "answer" => "putin@hotmail.com"},
          %{"question" => "snapchat", "answer" => "zelensky"},
          %{"question" => "messenger", "answer" => "zelensky"},
          %{"question" => "imessage", "answer" => "+79169752435"},
          %{"question" => "imessage", "answer" => "zelensky@free.co"},
          %{"question" => "signal", "answer" => "+79169752435"},
          %{"question" => "twitter", "answer" => "zelensky"},
          # would be rendered in v6.2.0 and removed in lower versions
          %{
            "s3_key" => "038fbd69-ba44-42c2-8086-5213ff093ad5",
            "duration" => 4.952947845804989,
            "question" => "audio",
            "waveform" =>
              "B7UZsWtPLtbgYg1SRenEdP154VNLVXTQMaQUQkoh55hSCimnEGIIIcSUUkwhhJBSjDGGHINOOqYUckophJQC"
          }
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
                   "url" => "https://t.me/putin"
                 },
                 %{
                   "answer" => "79169752435",
                   "question" => "whatsapp",
                   "url" => "https://wa.me/79169752435"
                 },
                 %{
                   "answer" => "putin",
                   "question" => "instagram",
                   "url" => "https://instagram.com/putin"
                 },
                 %{"answer" => "putin@hotmail.com", "question" => "email"},
                 %{
                   "answer" => "zelensky",
                   "question" => "snapchat",
                   "url" => "https://www.snapchat.com/add/zelensky"
                 },
                 %{
                   "answer" => "zelensky",
                   "question" => "messenger",
                   "url" => "https://m.me/zelensky"
                 },
                 %{"answer" => "+79169752435", "question" => "imessage"},
                 %{"answer" => "zelensky@free.co", "question" => "imessage"},
                 %{
                   "answer" => "+79169752435",
                   "question" => "signal",
                   "url" => "https://signal.me/#p/+79169752435"
                 },
                 %{
                   "answer" => "zelensky",
                   "question" => "twitter",
                   "url" => "https://twitter.com/zelensky"
                 }
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

  test "v6.2.0", %{story: story} do
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
                   "url" => "https://t.me/putin"
                 },
                 %{
                   "answer" => "79169752435",
                   "question" => "whatsapp",
                   "url" => "https://wa.me/79169752435"
                 },
                 %{
                   "answer" => "putin",
                   "question" => "instagram",
                   "url" => "https://instagram.com/putin"
                 },
                 %{"answer" => "putin@hotmail.com", "question" => "email"},
                 %{
                   "answer" => "zelensky",
                   "question" => "snapchat",
                   "url" => "https://www.snapchat.com/add/zelensky"
                 },
                 %{
                   "answer" => "zelensky",
                   "question" => "messenger",
                   "url" => "https://m.me/zelensky"
                 },
                 %{"answer" => "+79169752435", "question" => "imessage"},
                 %{"answer" => "zelensky@free.co", "question" => "imessage"},
                 %{
                   "answer" => "+79169752435",
                   "question" => "signal",
                   "url" => "https://signal.me/#p/+79169752435"
                 },
                 %{
                   "answer" => "zelensky",
                   "question" => "twitter",
                   "url" => "https://twitter.com/zelensky"
                 },
                 %{
                   "duration" => 4.952947845804989,
                   "question" => "audio",
                   "s3_key" => "038fbd69-ba44-42c2-8086-5213ff093ad5",
                   "url" => audio_url,
                   "waveform" =>
                     "B7UZsWtPLtbgYg1SRenEdP154VNLVXTQMaQUQkoh55hSCimnEGIIIcSUUkwhhJBSjDGGHINOOqYUckophJQC"
                 }
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
               _version = "6.2.0",
               _screen_width = 1200,
               _env = :feed
             )

    # audio url looks like:
    #  "https://pretend-this-is-real.s3.amazonaws.com/"<>
    #  "038fbd69-ba44-42c2-8086-5213ff093ad5"

    assert %URI{
             authority: "pretend-this-is-real.s3.amazonaws.com",
             fragment: nil,
             host: "pretend-this-is-real.s3.amazonaws.com",
             path: "/038fbd69-ba44-42c2-8086-5213ff093ad5",
             port: 443,
             query: _query,
             scheme: "https",
             userinfo: nil
           } = URI.parse(audio_url)
  end
end
