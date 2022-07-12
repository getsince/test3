defmodule T.Factory do
  use ExMachina.Ecto, repo: T.Repo

  alias T.Accounts.{User, Profile, GenderPreference, APNSDevice, UserToken}
  alias T.Feeds.{SeenProfile, FeedLimit}
  alias T.Matches.{Match, MatchEvent}

  alias T.News

  def user_factory do
    %User{apple_id: apple_id()}
  end

  def seen_profile_factory do
    %SeenProfile{}
  end

  def feed_limit_factory do
    %FeedLimit{}
  end

  def profile_factory do
    %Profile{
      user: build(:user),
      last_active: DateTime.truncate(DateTime.utc_now(), :second),
      hidden?: false,
      gender: "M"
    }
  end

  def match_factory do
    %Match{}
  end

  def match_event_factory do
    %MatchEvent{}
  end

  def gender_preference_factory do
    %GenderPreference{}
  end

  def user_token_factory do
    token = :crypto.strong_rand_bytes(32)
    %UserToken{token: token, context: "mobile"}
  end

  def apns_device_factory do
    alias T.PushNotifications.APNS

    user = build(:user)

    %APNSDevice{
      user: user,
      topic: APNS.default_topic(),
      env: "sandbox",
      locale: "en",
      token: build(:user_token, user: user)
    }
  end

  def apple_id do
    # 000701.5bccb2a610e04475a96dbe39e47cda09.1630
    # 001848.6244ee9f0798419db44fbedac8861ce1.1236
    # 000822.7fc739b031e542e19fd7b877cdd23122.2012
    rand = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    "000701." <> rand <> ".1630"
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
            "answer" => "durov",
            "question" => "telegram",
            "position" => [150, 150]
          }
        ]
      }
    ]
  end

  # https://yandex.com/maps/-/CCUmFHtcGA
  def moscow_location do
    [lat: 55.755516, lon: 37.615040]
  end

  # https://yandex.com/maps/-/CCUmFHtYpB
  def apple_location do
    [lat: 37.331647, lon: -122.029970]
  end

  def default_location, do: %Geo.Point{coordinates: {0, 0}, srid: 4326}

  def onboarding_attrs(opts \\ []) do
    gender = opts[:gender] || "M"
    %{lat: lat, lon: lon} = Map.new(opts[:location] || [lat: 55.755833, lon: 37.617222])

    story =
      if Keyword.has_key?(opts, :story) do
        opts[:story]
      else
        profile_story()
      end

    %{
      story: story,
      latitude: lat,
      longitude: lon,
      birthdate: opts[:birthdate] || "1998-10-28",
      gender: gender,
      name: opts[:name] || "that",
      gender_preference: opts[:accept_genders] || ["F"],
      distance: opts[:distance],
      address:
        opts[:address] ||
          %{
            "en_US" => %{
              "city" => "Buenos Aires",
              "state" => "Autonomous City of Buenos Aires",
              "country" => "Argentina",
              "iso_country_code" => "AR"
            }
          },
      max_age: opts[:max_age],
      min_age: opts[:min_age]
    }
  end

  alias T.{Accounts, Repo}

  def registered_user(apple_id \\ apple_id(), last_active \\ DateTime.utc_now()) do
    {:ok, user} = Accounts.register_user_with_apple_id(%{"apple_id" => apple_id}, last_active)
    user
  end

  def onboarded_user(opts \\ []) do
    user =
      registered_user(opts[:apple_id] || apple_id(), opts[:last_active] || DateTime.utc_now())

    News.mark_seen(user.id)
    {:ok, profile} = Accounts.onboard_profile(user.id, onboarding_attrs(opts))
    %Accounts.User{user | profile: profile}
  end

  def set_like_ratio(%Accounts.User{id: user_id}, ratio) do
    set_like_ratio(user_id, ratio)
  end

  def set_like_ratio(%{user_id: user_id}, ratio) do
    set_like_ratio(user_id, ratio)
  end

  def set_like_ratio(user_id, ratio) when is_binary(user_id) do
    import Ecto.Query

    {1, _} =
      "profiles"
      |> where(user_id: type(^user_id, Ecto.UUID))
      |> Repo.update_all(set: [like_ratio: ratio])
  end

  def msk(date, time) do
    date
    |> DateTime.new!(time, "Europe/Moscow")
    |> DateTime.shift_zone!("Etc/UTC")
  end
end
