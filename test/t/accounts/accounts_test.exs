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
               birthdate: ["can't be blank"]
             }

      assert {:ok, profile} =
               Accounts.onboard_profile(profile, %{
                 gender: "M",
                 name: "that",
                 birthdate: "1998-10-28 13:57:36",
                 latitude: 50,
                 longitude: 50
               })

      profile = Profile |> Repo.get!(profile.user_id) |> Repo.preload(:user)

      # no story, so still hidden
      assert profile.hidden?
      assert profile.user.onboarded_at

      assert %Profile{
               gender: "M",
               name: "that",
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
end
