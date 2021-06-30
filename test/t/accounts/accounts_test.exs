defmodule T.AccountsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: Repo

  alias T.Accounts
  alias T.Accounts.{Profile, PasswordlessAuth}

  doctest PasswordlessAuth, import: true

  describe "save_photo/2" do
    test "pushes photo into existing profile's photos array" do
      %{user: user} = insert(:profile)
      assert {1, [["folder/file.jpg"]]} = Accounts.save_photo(user, "folder/file.jpg")

      assert {1, [["folder/file.jpg", "folder/file2.jpg"]]} =
               Accounts.save_photo(user, "folder/file2.jpg")
    end
  end

  # TODO empty arrays pass changesets
  describe "onboard_profile/2" do
    test "in one step" do
      profile = insert(:profile, hidden?: true)
      profile = Profile |> Repo.get!(profile.user_id) |> Repo.preload(:user)

      assert profile.hidden? == true
      refute profile.user.onboarded_at

      assert {:error, changeset} = Accounts.onboard_profile(profile, %{})

      assert errors_on(changeset) == %{
               # TODO
               #  gender: ["can't be blank"],
               name: ["can't be blank"],
               location: ["can't be blank"]
             }

      apple_music_song = apple_music_song()

      assert {:ok, profile} =
               Accounts.onboard_profile(profile, %{
                 song: apple_music_song,
                 gender: "M",
                 name: "that",
                 latitude: 50,
                 longitude: 50
               })

      profile = Profile |> Repo.get!(profile.user_id) |> Repo.preload(:user)

      # no story, so still hidden
      assert profile.hidden?
      assert profile.user.onboarded_at

      assert %Profile{
               song: ^apple_music_song,
               gender: "M",
               name: "that",
               times_liked: 0,
               story: nil
             } = profile

      assert {:ok, profile} =
               Accounts.update_profile(profile, %{
                 story: profile_story()
               })

      profile = Profile |> Repo.get!(profile.user_id) |> Repo.preload(:user)

      assert profile.hidden? == false
      assert profile.user.onboarded_at
    end
  end

  describe "update_last_active/1" do
    test "it works" do
      {:ok, %{profile: %Profile{user_id: user_id, last_active: last_active}}} =
        Accounts.register_user(%{phone_number: phone_number()})

      assert last_active

      # TODO
      :timer.sleep(1000)

      assert {1, nil} == Accounts.update_last_active(user_id)
      refute last_active == Accounts.get_profile!(user_id).last_active
    end
  end
end
