defmodule T.Factory do
  use ExMachina.Ecto, repo: T.Repo
  alias T.Accounts.{User, Profile}
  alias T.Feeds.{ProfileLike, SeenProfile, Feed, PersonalityOverlap}
  alias T.Matches.{Match, Message, Timeslot}

  def user_factory do
    %User{phone_number: phone_number()}
  end

  def profile_factory do
    %Profile{
      user: build(:user),
      # last_active: DateTime.truncate(DateTime.utc_now(), :second),
      hidden?: false,
      gender: "M"
    }
  end

  def feed_factory do
    %Feed{}
  end

  def like_factory do
    %ProfileLike{}
  end

  def seen_factory do
    %SeenProfile{}
  end

  def personality_overlap_factory do
    %PersonalityOverlap{}
  end

  def match_factory do
    %Match{}
  end

  def message_factory do
    %Message{}
  end

  def timeslot_factory do
    %Timeslot{}
  end

  def phone_number do
    rand = to_string(:rand.uniform(9_999_999))
    "+7916" <> String.pad_leading(rand, 7, "0")
  end

  def apple_music_song do
    %{
      "data" => [
        %{
          "attributes" => %{
            "albumName" => "Born In the U.S.A.",
            "artistName" => "Bruce Springsteen",
            "artwork" => %{
              "bgColor" => "d9c8b6",
              "height" => 6000,
              "textColor1" => "100707",
              "textColor2" => "441016",
              "textColor3" => "382e2a",
              "textColor4" => "623436",
              "url" =>
                "https://is1-ssl.mzstatic.com/image/thumb/Music128/v4/1d/b0/2d/1db02d23-6e40-ae43-29c9-ff31a854e8aa/074643865326.jpg/{w}x{h}bb.jpeg",
              "width" => 6000
            },
            "composerName" => "Bruce Springsteen",
            "discNumber" => 1,
            "durationInMillis" => 245_298,
            "genreNames" => ["Rock", "Music"],
            "hasLyrics" => true,
            "isrc" => "USSM18400416",
            "name" => "Dancing In the Dark",
            "playParams" => %{"id" => "203709340", "kind" => "song"},
            "previews" => [
              %{
                "url" =>
                  "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview71/v4/ab/b3/48/abb34824-1510-708e-57d7-870206be5ba2/mzaf_8515316732595919510.plus.aac.p.m4a"
              }
            ],
            "releaseDate" => "1984-05-04",
            "trackNumber" => 11,
            "url" => "https://music.apple.com/us/album/dancing-in-the-dark/203708420?i=203709340"
          },
          "href" => "/v1/catalog/us/songs/203709340",
          "id" => "203709340",
          "relationships" => %{
            "albums" => %{
              "data" => [
                %{
                  "href" => "/v1/catalog/us/albums/203708420",
                  "id" => "203708420",
                  "type" => "albums"
                }
              ],
              "href" => "/v1/catalog/us/songs/203709340/albums"
            },
            "artists" => %{
              "data" => [
                %{
                  "href" => "/v1/catalog/us/artists/178834",
                  "id" => "178834",
                  "type" => "artists"
                }
              ],
              "href" => "/v1/catalog/us/songs/203709340/artists"
            }
          },
          "type" => "songs"
        }
      ]
    }
  end

  def profile_story do
    [
      %{
        "background" => %{
          "s3_key" => "photo.jpg"
        },
        "labels" => [
          %{
            "type" => "text",
            "value" => "just some text",
            "dimensions" => [400, 800],
            "position" => [100, 100],
            "rotation" => 21,
            "zoom" => 1.2
          },
          %{
            "type" => "answer",
            "answer" => "msu",
            "question" => "university",
            "value" => "🥊\nменя воспитала улица",
            "dimensions" => [400, 800],
            "position" => [150, 150]
          }
        ]
      }
    ]
  end

  def onboarding_attrs(gender \\ "M") do
    %{
      story: profile_story(),
      song: apple_music_song(),
      latitude: 50.0,
      longitude: 50.0,
      gender: gender,
      name: "that"
    }
  end

  alias T.Accounts

  def registered_user(phone_number \\ phone_number()) do
    {:ok, user} = Accounts.register_user(%{"phone_number" => phone_number})
    user
  end

  def onboarded_user(user \\ registered_user()) do
    {:ok, profile} = Accounts.onboard_profile(user.profile, onboarding_attrs())
    %Accounts.User{user | profile: profile}
  end
end
