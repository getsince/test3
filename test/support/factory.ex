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

  def onboarding_attrs(gender \\ "M") do
    %{
      birthdate: "1992-12-12",
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
