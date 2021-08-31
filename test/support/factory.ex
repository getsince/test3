defmodule T.Factory do
  use ExMachina.Ecto, repo: T.Repo
  alias T.Accounts.{User, Profile, GenderPreference}
  alias T.Matches.{Match, Timeslot}
  alias T.Calls.Call

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

  def gender_preference_factory do
    %GenderPreference{}
  end

  def phone_number do
    rand = to_string(:rand.uniform(9_999_999))
    "+7916" <> String.pad_leading(rand, 7, "0")
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
      latitude: 50.0,
      longitude: 50.0,
      gender: gender,
      name: "that"
    }
  end

  alias T.Accounts

  def registered_user(phone_number \\ phone_number()) do
    {:ok, user} = Accounts.register_user_with_phone(%{"phone_number" => phone_number})
    user
  end

  def onboarded_user(user \\ registered_user()) do
    {:ok, profile} = Accounts.onboard_profile(user.profile, onboarding_attrs())
    %Accounts.User{user | profile: profile}
  end
end
