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
end
