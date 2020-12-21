defmodule T.AccountsTest do
  use T.DataCase, async: true
  alias T.Accounts
  alias T.Accounts.User

  describe "save_photo/2" do
    test "pushes photo into existing profile's photos array" do
      %{user: user} = insert(:profile)
      assert {1, [["folder/file.jpg"]]} = Accounts.save_photo(user, "folder/file.jpg")

      assert {1, [["folder/file.jpg", "folder/file2.jpg"]]} =
               Accounts.save_photo(user, "folder/file2.jpg")
    end
  end

  describe "ensure_profile/1" do
    test "creates a missing profile for existing user" do
      user = insert(:user, phone_number: "+79999999999")
      assert %User{profile: %User.Profile{}} = Accounts.ensure_profile(user)
      assert Repo.get_by(User.Profile, user_id: user.id)
    end

    test "returns existing profile" do
      %{user: user} = _p1 = insert(:profile, user: build(:user, phone_number: "+79999999999"))
      assert %User{profile: _p2} = Accounts.ensure_profile(user)
      # assert_structs_equal(p1, p2, User.Profile.__schema__(:fields))
    end
  end

  describe "update_photos/2" do
    test "with valid attrs" do
      profile = insert(:profile)

      assert {:ok, %User.Profile{photos: ["a", "b", "c", "d"]}} =
               Accounts.update_photos(profile, %{photos: ["a", "b", "c", "d"]}, validate?: true)
    end
  end

  describe "update_general_profile_info/2" do
    test "with valid attrs" do
      profile = insert(:profile)

      assert {:ok,
              %User.Profile{
                gender: "M",
                birthdate: ~D[2000-01-01],
                name: "Some Name",
                home_city: "Moscow",
                height: 150
              }} =
               Accounts.update_general_profile_info(profile, %{
                 gender: "M",
                 birthdate: "2000-01-01",
                 name: "Some Name",
                 home_city: "Moscow",
                 height: 150
               })
    end
  end

  describe "update_work_and_education_info/2" do
    test "with valid attrs" do
      profile = insert(:profile)

      assert {:ok,
              %User.Profile{
                university: "HSE",
                major: "Econ",
                occupation: "Accountant",
                job: "Unemployed"
              }} =
               Accounts.update_work_and_education_info(profile, %{
                 university: "HSE",
                 major: "Econ",
                 occupation: "Accountant",
                 job: "Unemployed"
               })
    end
  end

  describe "update_about_self_info/2" do
    test "with valid attrs" do
      profile = insert(:profile)

      assert {:ok,
              %User.Profile{
                most_important_in_life: "dunno",
                interests: ["running", "swimming", "walking", "crawling"],
                first_date_idea: "circus",
                free_form: "hm dunno"
              }} =
               Accounts.update_about_self_info(profile, %{
                 most_important_in_life: "dunno",
                 interests: ["running", "swimming", "walking", "crawling"],
                 first_date_idea: "circus",
                 free_form: "hm dunno"
               })
    end
  end

  describe "update_tastes/2" do
    test "with valid attrs" do
      profile = insert(:profile)

      assert {:ok,
              %User.Profile{
                music: ["rice"],
                sports: ["bottles"],
                alcohol: "not really",
                smoking: "nah",
                books: ["lol no"],
                tv_shows: ["no"],
                currently_studying: ["nah"]
              }} =
               Accounts.update_tastes(profile, %{
                 music: ["rice"],
                 sports: ["bottles"],
                 alcohol: "not really",
                 smoking: "nah",
                 books: ["lol no"],
                 tv_shows: ["no"],
                 currently_studying: ["nah"]
               })
    end
  end

  # TODO empty arrays pass changesets
  describe "finish_onboarding/1" do
    test "with valid data" do
      profile = insert(:profile)

      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Accounts.finish_onboarding(profile.user_id)

      assert errors_on(changeset) == %{
               birthdate: ["can't be blank"],
               first_date_idea: ["can't be blank"],
               gender: ["can't be blank"],
               height: ["can't be blank"],
               home_city: ["can't be blank"],
               interests: ["should have at least 2 item(s)"],
               most_important_in_life: ["can't be blank"],
               name: ["can't be blank"],
               photos: ["should have at least 3 item(s)"],
               tastes: ["should have at least 7 tastes"]
             }

      assert {:ok, profile} =
               Accounts.update_photos(profile, %{photos: ["a", "b", "c"]}, validate?: true)

      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Accounts.finish_onboarding(profile.user_id)

      assert errors_on(changeset) == %{
               birthdate: ["can't be blank"],
               first_date_idea: ["can't be blank"],
               gender: ["can't be blank"],
               height: ["can't be blank"],
               home_city: ["can't be blank"],
               most_important_in_life: ["can't be blank"],
               name: ["can't be blank"],
               interests: ["should have at least 2 item(s)"],
               tastes: ["should have at least 7 tastes"]
             }

      assert {:ok, profile} =
               Accounts.update_general_profile_info(profile, %{
                 gender: "M",
                 birthdate: "2000-01-01",
                 name: "Some Name",
                 home_city: "Moscow",
                 height: 150
               })

      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Accounts.finish_onboarding(profile.user_id)

      assert errors_on(changeset) == %{
               first_date_idea: ["can't be blank"],
               most_important_in_life: ["can't be blank"],
               interests: ["should have at least 2 item(s)"],
               tastes: ["should have at least 7 tastes"]
             }

      assert {:ok, profile} =
               Accounts.update_work_and_education_info(profile, %{
                 university: "HSE",
                 major: "Econ",
                 occupation: "Accountant",
                 job: "Unemployed"
               })

      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Accounts.finish_onboarding(profile.user_id)

      assert errors_on(changeset) == %{
               first_date_idea: ["can't be blank"],
               most_important_in_life: ["can't be blank"],
               interests: ["should have at least 2 item(s)"],
               tastes: ["should have at least 7 tastes"]
             }

      assert {:ok, profile} =
               Accounts.update_about_self_info(profile, %{
                 most_important_in_life: "dunno",
                 interests: ["running", "swimming", "walking", "crawling"],
                 first_date_idea: "circus",
                 free_form: "hm dunno"
               })

      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Accounts.finish_onboarding(profile.user_id)

      assert errors_on(changeset) == %{
               tastes: ["should have at least 7 tastes"]
             }

      assert {:ok, profile} =
               Accounts.update_tastes(profile, %{
                 music: ["rice"],
                 sports: ["bottles"],
                 alcohol: "not really",
                 smoking: "nah",
                 books: ["lol no"],
                 tv_shows: ["no"],
                 currently_studying: ["nah"]
               })

      assert {:ok, %User{onboarded_at: onboarded_at}} =
               Accounts.finish_onboarding(profile.user_id)

      assert onboarded_at
    end
  end
end
