defmodule T.Factory do
  use ExMachina.Ecto, repo: T.Repo
  alias T.Accounts.{User, Profile, GenderPreference}
  alias T.Feeds.SeenProfile
  alias T.Matches.{Match, Timeslot, ExpiredMatch, MatchEvent}
  alias T.Calls.Call

  def user_factory do
    %User{apple_id: apple_id()}
  end

  def seen_profile_factory do
    %SeenProfile{}
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

  def timeslot_factory do
    %Timeslot{}
  end

  def call_factory do
    %Call{
      caller: build(:user),
      called: build(:user)
    }
  end

  def expired_match_factory do
    %ExpiredMatch{}
  end

  def match_event_factory do
    %MatchEvent{}
  end

  def gender_preference_factory do
    %GenderPreference{}
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

  # https://yandex.com/maps/-/CCUmFHtcGA
  def moscow_location do
    [lat: 55.755516, lon: 37.615040]
  end

  # https://yandex.com/maps/-/CCUmFHtYpB
  def apple_location do
    [lat: 37.331647, lon: -122.029970]
  end

  def onboarding_attrs(opts \\ []) do
    gender = opts[:gender] || "M"
    %{lat: lat, lon: lon} = Map.new(opts[:location] || [lat: 55.755833, lon: 37.617222])

    %{
      story: opts[:story] || profile_story(),
      latitude: lat,
      longitude: lon,
      birthdate: opts[:birthdate] || "1998-10-28",
      gender: gender,
      name: opts[:name] || "that",
      times_liked: opts[:times_liked] || 0,
      filters: %{genders: opts[:accept_genders] || ["F"]}
    }
  end

  alias T.Accounts

  def registered_user(apple_id \\ apple_id(), last_active \\ DateTime.utc_now()) do
    {:ok, user} = Accounts.register_user_with_apple_id(%{"apple_id" => apple_id}, last_active)
    user
  end

  def onboarded_user(opts \\ []) do
    user =
      registered_user(opts[:apple_id] || apple_id(), opts[:last_active] || DateTime.utc_now())

    {:ok, profile} = Accounts.onboard_profile(user.profile, onboarding_attrs(opts))
    %Accounts.User{user | profile: profile}
  end
end
