defmodule T.ContactReplacementTest do
  use T.DataCase, async: true
  alias ContactCtx, as: Ctx

  test "parse_replacement/1" do
    assert [%{k: "telegram", v: "durov"}] = Ctx.parse_replacement("telegram,durov")
    assert [%{k: "telegram", v: "durov", dx: 20}] = Ctx.parse_replacement("telegram,durov,20")

    assert [%{k: "telegram", v: "durov", dx: 0, dy: 20}] =
             Ctx.parse_replacement("telegram,durov,0,20")

    assert [%{k: "telegram", v: "durov", dx: 0, dy: 20}] =
             Ctx.parse_replacement("telegram,durov,,20")

    assert [%{k: :keep, v: "text change"}] = Ctx.parse_replacement(",text change")

    assert [%{k: :keep, v: "text change"}, %{k: "telegram", v: "durov", dx: 20}] =
             Ctx.parse_replacement(",text change\ntelegram,durov,20")
  end

  test "add_contacts/4" do
    story = [
      %{
        "background" => %{"s3_key" => "image1.jpg"},
        "labels" => [
          %{
            "value" => "пиши мне сразу на тг или инст @durov",
            "position" => [200, 200],
            "rotation" => 1
          },
          %{
            "value" => "пиши мне сразу на тг или инст @durov",
            "position" => [200, 200],
            "rotation" => 2
          }
        ],
        "size" => [400, 400]
      },
      %{
        "background" => %{"s3_key" => "image2.jpg"},
        "labels" => [
          %{
            "value" => "пиши мне сразу на тг или инст @durov",
            "position" => [200, 200],
            "rotation" => 3
          },
          %{
            "value" => "пиши мне сразу на тг или инст @durov",
            "position" => [200, 200],
            "rotation" => 4
          }
        ],
        "size" => [400, 400]
      }
    ]

    replacement = Ctx.parse_replacement("telegram,durov")

    # replace labels on first page / first label
    assert Ctx.add_contacts(story, _page_id = 0, _label_id = 0, replacement) == [
             %{
               "background" => %{"s3_key" => "image1.jpg"},
               "labels" => [
                 %{
                   "position" => [200, 200],
                   "rotation" => 1,
                   # text-context = true are not rendered in v6.0.0
                   "text-contact" => true,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 },
                 %{
                   # new contact
                   "question" => "telegram",
                   "answer" => "durov",
                   "position" => [200, 200],
                   "rotation" => 1
                 },
                 %{
                   "position" => [200, 200],
                   "rotation" => 2,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 }
               ],
               "size" => [400, 400]
             },
             # second page is unchanged
             %{
               "background" => %{"s3_key" => "image2.jpg"},
               "labels" => [
                 %{
                   "position" => [200, 200],
                   "rotation" => 3,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 },
                 %{
                   "position" => [200, 200],
                   "rotation" => 4,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 }
               ],
               "size" => [400, 400]
             }
           ]

    assert Ctx.add_contacts(story, _page_id = 0, _label_id = 1, replacement) == [
             %{
               "background" => %{"s3_key" => "image1.jpg"},
               "labels" => [
                 %{
                   "position" => [200, 200],
                   "rotation" => 1,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 },
                 %{
                   "position" => [200, 200],
                   "rotation" => 2,
                   "text-contact" => true,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 },
                 %{
                   "question" => "telegram",
                   "answer" => "durov",
                   "position" => [200, 200],
                   "rotation" => 2
                 }
               ],
               "size" => [400, 400]
             },
             %{
               "background" => %{"s3_key" => "image2.jpg"},
               "labels" => [
                 %{
                   "position" => [200, 200],
                   "rotation" => 3,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 },
                 %{
                   "position" => [200, 200],
                   "rotation" => 4,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 }
               ],
               "size" => [400, 400]
             }
           ]

    assert Ctx.add_contacts(story, _page_id = 1, _label_id = 0, replacement) == [
             %{
               "background" => %{"s3_key" => "image1.jpg"},
               "labels" => [
                 %{
                   "position" => [200, 200],
                   "rotation" => 1,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 },
                 %{
                   "position" => [200, 200],
                   "rotation" => 2,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 }
               ],
               "size" => [400, 400]
             },
             %{
               "background" => %{"s3_key" => "image2.jpg"},
               "labels" => [
                 %{
                   "position" => [200, 200],
                   "rotation" => 3,
                   "text-contact" => true,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 },
                 %{
                   "question" => "telegram",
                   "answer" => "durov",
                   "position" => [200, 200],
                   "rotation" => 3
                 },
                 %{
                   "position" => [200, 200],
                   "rotation" => 4,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 }
               ],
               "size" => [400, 400]
             }
           ]

    assert Ctx.add_contacts(story, _page_id = 1, _label_id = 1, replacement) == [
             %{
               "background" => %{"s3_key" => "image1.jpg"},
               "labels" => [
                 %{
                   "position" => [200, 200],
                   "rotation" => 1,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 },
                 %{
                   "position" => [200, 200],
                   "rotation" => 2,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 }
               ],
               "size" => [400, 400]
             },
             %{
               "background" => %{"s3_key" => "image2.jpg"},
               "labels" => [
                 %{
                   "position" => [200, 200],
                   "rotation" => 3,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 },
                 %{
                   "position" => [200, 200],
                   "rotation" => 4,
                   "text-contact" => true,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 },
                 %{
                   "question" => "telegram",
                   "answer" => "durov",
                   "position" => [200, 200],
                   "rotation" => 4
                 }
               ],
               "size" => [400, 400]
             }
           ]

    replacement =
      Ctx.parse_replacement(",пиши мне сразу на тг или инст\ntelegram,durov,,20\ni,durov,,40")

    assert Ctx.add_contacts(story, _page_id = 1, _label_id = 1, replacement) == [
             %{
               "background" => %{"s3_key" => "image1.jpg"},
               "labels" => [
                 %{
                   "position" => [200, 200],
                   "rotation" => 1,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 },
                 %{
                   "position" => [200, 200],
                   "rotation" => 2,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 }
               ],
               "size" => [400, 400]
             },
             %{
               "background" => %{"s3_key" => "image2.jpg"},
               "labels" => [
                 %{
                   "position" => [200, 200],
                   "rotation" => 3,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 },
                 %{
                   "position" => [200, 200],
                   "rotation" => 4,
                   "text-contact" => true,
                   "value" => "пиши мне сразу на тг или инст @durov"
                 },
                 %{
                   "position" => [200, 200],
                   "rotation" => 4,
                   "value" => "пиши мне сразу на тг или инст",
                   "text-change" => true
                 },
                 %{
                   "question" => "telegram",
                   "answer" => "durov",
                   "rotation" => 4,
                   "position" => [200, 220]
                 },
                 %{
                   "question" => "instagram",
                   "answer" => "durov",
                   "rotation" => 4,
                   "position" => [200, 240]
                 }
               ],
               "size" => [400, 400]
             }
           ]
  end

  # TODO
  @tag skip: true
  test "cas_story/3" do
  end
end
