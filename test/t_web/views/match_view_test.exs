defmodule TWeb.MatchViewTest do
  use TWeb.ConnCase, async: true
  alias T.Matches.Match
  alias T.Calls.Voicemail
  alias T.Feeds.FeedProfile

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "renders voicemail" do
    mate_id = "0000017e-116e-e580-06e9-e8bbc6570000"

    match = %Match{
      id: "0000017e-0be1-dc5f-06e9-e8bbc6570000",
      voicemail: [
        %Voicemail{
          id: "0000017e-0c0c-d02f-06e9-e8bbc6570000",
          caller_id: mate_id,
          s3_key: "f2cb52d1-423e-4fd9-be7c-24287e0d977c",
          inserted_at: ~N[2021-12-30 15:54:41]
        },
        %Voicemail{
          id: "0000017e-0c0c-ef71-06e9-e8bbc6570000",
          caller_id: mate_id,
          s3_key: "de0253e8-a0f3-4206-80a3-2f26a0fffb29",
          inserted_at: ~N[2021-12-30 15:54:41]
        }
      ]
    }

    profile = %FeedProfile{
      user_id: mate_id,
      story: [],
      gender: "F",
      name: "Pobeda"
    }

    assigns = %{
      id: match.id,
      voicemail: match.voicemail,
      profile: profile,
      screen_width: 1000,
      # since voicemail no longer exists in v6.0.0, I'm using the last support v5 version here
      version: "5.2.3"
    }

    %{"voicemail" => voicemail} = rendered = render(TWeb.MatchView, "match.json", assigns)

    assert rendered == %{
             "id" => match.id,
             "profile" => %{
               gender: "F",
               name: "Pobeda",
               story: [],
               user_id: profile.user_id
             },
             "voicemail" => voicemail
           }

    assert %{
             "caller_id" => ^mate_id,
             "messages" => [
               %{
                 id: "0000017e-0c0c-d02f-06e9-e8bbc6570000",
                 url: _v1_url,
                 inserted_at: ~U[2021-12-30 15:54:41Z],
                 s3_key: "f2cb52d1-423e-4fd9-be7c-24287e0d977c"
               },
               %{
                 id: "0000017e-0c0c-ef71-06e9-e8bbc6570000",
                 url: v2_url,
                 inserted_at: ~U[2021-12-30 15:54:41Z],
                 s3_key: "de0253e8-a0f3-4206-80a3-2f26a0fffb29"
               }
             ]
           } = voicemail

    # voicemail url looks like:
    # "https://s3.eu-north-1.amazonaws.com/pretend-this-is-real/" <>
    #   "de0253e8-a0f3-4206-80a3-2f26a0fffb29?X-Amz-Algorithm=AWS4-HMAC-SHA256&" <>
    #   "X-Amz-Credential=AWS_ACCESS_KEY_ID%2F20211230%2Feu-north-1%2Fs3%2Faws4_request&" <>
    #   "X-Amz-Date=20211230T151714Z&X-Amz-Expires=3600&X-Amz-SignedHeaders=host&" <>
    #   "X-Amz-Signature=bd5828283fe46617894a928b1734104c8c03bc17fe883fcec496848e23316367"

    assert %URI{
             authority: "s3.eu-north-1.amazonaws.com",
             fragment: nil,
             host: "s3.eu-north-1.amazonaws.com",
             path: "/pretend-this-is-real/de0253e8-a0f3-4206-80a3-2f26a0fffb29",
             port: 443,
             query: query,
             scheme: "https",
             userinfo: nil
           } = URI.parse(v2_url)

    assert %{
             "X-Amz-Algorithm" => "AWS4-HMAC-SHA256",
             "X-Amz-Credential" => _creds,
             "X-Amz-Date" => _date,
             "X-Amz-Expires" => "3600" = _one_hour,
             "X-Amz-Signature" => _signature,
             "X-Amz-SignedHeaders" => "host"
           } = URI.decode_query(query)
  end
end
