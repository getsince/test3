defmodule T.Factory do
  use ExMachina.Ecto, repo: T.Repo
  alias T.Accounts.{User, Profile}
  alias T.Feeds.{ProfileLike, ProfileDislike, SeenProfile, Feed, PersonalityOverlap}
  alias T.Matches.{Match, Message}

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

  def dislike_factory do
    %ProfileDislike{}
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

  def onboarding_attrs(gender \\ "M") do
    %{
      birthdate: "1992-12-12",
      song: apple_music_song(),
      city: "Moscow",
      first_date_idea: "asdf",
      gender: gender,
      height: 120,
      interests: ["this", "that"],
      most_important_in_life: "this",
      name: "that",
      photos: ["a", "b", "c", "d"],
      tastes: %{
        music: ["rice"],
        sports: ["bottles"],
        alcohol: "not really",
        smoking: "nah",
        books: ["lol no"],
        tv_shows: ["no"],
        currently_studying: ["nah"]
      }
    }
  end

  alias T.Accounts

  def onboarded_user do
    {:ok, user} = Accounts.register_user(%{"phone_number" => phone_number()})
    {:ok, profile} = Accounts.onboard_profile(user.profile, onboarding_attrs())
    %Accounts.User{user | profile: profile}
  end
end
