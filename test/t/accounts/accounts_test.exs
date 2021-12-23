defmodule T.AccountsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: Repo

  alias T.Accounts
  alias T.Accounts.Profile

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
               location: ["can't be blank"],
               birthdate: ["can't be blank"],
               gender_preference: ["can't be blank"]
             }

      assert {:ok, profile} =
               Accounts.onboard_profile(profile, %{
                 gender: "M",
                 name: "that",
                 birthdate: "1998-10-28",
                 latitude: 50,
                 longitude: 50,
                 gender_preference: ["F", "M", "N"],
                 min_age: 18,
                 max_age: 100,
                 distance: 20000
               })

      profile = Profile |> Repo.get!(profile.user_id) |> Repo.preload(:user)

      # no story, so still hidden
      assert profile.hidden?
      assert profile.user.onboarded_at

      assert %Profile{
               gender: "M",
               name: "that",
               birthdate: ~D[1998-10-28],
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
        Accounts.register_user_with_apple_id(%{"apple_id" => apple_id()})

      assert last_active

      # TODO
      :timer.sleep(1000)

      assert {1, nil} == Accounts.update_last_active(user_id)
      refute last_active == Accounts.get_profile!(user_id).last_active
    end
  end

  describe "add_settings/1" do
    test "it works" do
      {:ok, %{profile: %Profile{audio_only: audio_only}}} =
        Accounts.register_user_with_apple_id(%{"apple_id" => apple_id()})

      assert audio_only == false
    end
  end

  describe "list_gender_preferences/1" do
    test "when user doesn't exist" do
      assert Accounts.list_gender_preferences(Ecto.UUID.generate()) == []
    end

    test "when user exists and has no preferences" do
      user = insert(:user)
      assert Accounts.list_gender_preferences(user.id) == []
    end

    test "when user exists and has preferences" do
      user = insert(:user)

      insert(:gender_preference, gender: "F", user_id: user.id)
      assert Accounts.list_gender_preferences(user.id) == ["F"]

      insert(:gender_preference, gender: "M", user_id: user.id)
      assert Accounts.list_gender_preferences(user.id) == ["F", "M"]
    end
  end

  describe "get_profile/1" do
    test "with gender preferences" do
      {:ok, %{profile: %Profile{user_id: user_id}}} =
        Accounts.register_user_with_apple_id(%{"apple_id" => apple_id()})

      insert(:gender_preference, gender: "F", user_id: user_id)
      insert(:gender_preference, gender: "N", user_id: user_id)

      assert ["F", "N"] == Accounts.get_profile!(user_id).gender_preference
    end

    test "with user settings" do
      {:ok, %{profile: %Profile{user_id: user_id}}} =
        Accounts.register_user_with_apple_id(%{"apple_id" => apple_id()})

      Accounts.set_audio_only(user_id, true)

      assert true == Accounts.get_profile!(user_id).audio_only
    end
  end

  describe "set_audio_only/2" do
    test "works" do
      {:ok, %{profile: %Profile{user_id: user_id}}} =
        Accounts.register_user_with_apple_id(%{"apple_id" => apple_id()})

      Accounts.set_audio_only(user_id, true)

      assert Accounts.UserSettings
             |> where(user_id: ^user_id)
             |> select([s], s.audio_only)
             |> T.Repo.one!() == true
    end
  end
end
