defmodule T.AccountsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: Repo

  alias T.Accounts
  alias T.Accounts.Profile

  describe "save_photo/2" do
    test "pushes photo into existing profile's photos array" do
      %{user: user} = insert(:profile)
      assert {1, [["folder/file.jpg"]]} = Accounts.save_photo(user, "folder/file.jpg")

      assert {1, [["folder/file.jpg", "folder/file2.jpg"]]} =
               Accounts.save_photo(user, "folder/file2.jpg")
    end
  end

  describe "update_photos/2" do
    @tag skip: true
    test "with valid attrs" do
      # profile = insert(:profile)

      # assert {:ok, %Profile{photos: ["a", "b", "c", "d"]}} =
      #          Accounts.update_photos(profile, %{photos: ["a", "b", "c", "d"]},
      #            validate_required?: true
      #          )
    end
  end

  describe "update_general_profile_info/2" do
    @tag skip: true
    test "with valid attrs" do
      # profile = insert(:profile)

      # assert {:ok,
      #         %Profile{
      #           gender: "M",
      #           birthdate: ~D[2000-01-01],
      #           name: "Some Name",
      #           city: "Moscow",
      #           height: 150
      #         }} =
      #          Accounts.update_general_profile_info(profile, %{
      #            gender: "M",
      #            birthdate: "2000-01-01",
      #            name: "Some Name",
      #            city: "Moscow",
      #            height: 150
      #          })
    end
  end

  describe "update_work_and_education_info/2" do
    @tag skip: true
    test "with valid attrs" do
      # profile = insert(:profile)

      # assert {:ok,
      #         %Profile{
      #           university: "HSE",
      #           major: "Econ",
      #           occupation: "Accountant",
      #           job: "Unemployed"
      #         }} =
      #          Accounts.update_work_and_education_info(profile, %{
      #            university: "HSE",
      #            major: "Econ",
      #            occupation: "Accountant",
      #            job: "Unemployed"
      #          })
    end
  end

  describe "update_about_self_info/2" do
    @tag skip: true
    test "with valid attrs" do
      # profile = insert(:profile)

      # assert {:ok,
      #         %Profile{
      #           most_important_in_life: "dunno",
      #           interests: ["running", "swimming", "walking", "crawling"],
      #           first_date_idea: "circus",
      #           free_form: "hm dunno"
      #         }} =
      #          Accounts.update_about_self_info(profile, %{
      #            most_important_in_life: "dunno",
      #            interests: ["running", "swimming", "walking", "crawling"],
      #            first_date_idea: "circus",
      #            free_form: "hm dunno"
      #          })
    end
  end

  describe "update_tastes/2" do
    @tag skip: true
    test "with valid attrs" do
      # profile = insert(:profile)

      # assert {:ok,
      #         %Profile{
      #           tastes: %{
      #             "music" => ["rice"],
      #             "sports" => ["bottles"],
      #             "alcohol" => "not really",
      #             "smoking" => "nah",
      #             "books" => ["lol no"],
      #             "tv_shows" => ["no"],
      #             "currently_studying" => ["nah"]
      #           }
      #         }} =
      #          Accounts.update_tastes(profile, %{
      #            tastes: %{
      #              music: ["rice"],
      #              sports: ["bottles"],
      #              alcohol: "not really",
      #              smoking: "nah",
      #              books: ["lol no"],
      #              tv_shows: ["no"],
      #              currently_studying: ["nah"]
      #            }
      #          })
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

    @tag skip: true
    test "step by step" do
      # profile = insert(:profile)

      # assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
      #          Accounts.onboard_profile(profile.user_id, %{})

      # assert errors_on(changeset) == %{
      #          birthdate: ["can't be blank"],
      #          first_date_idea: ["can't be blank"],
      #          gender: ["can't be blank"],
      #          height: ["can't be blank"],
      #          city: ["can't be blank"],
      #          interests: ["should have at least 2 item(s)"],
      #          most_important_in_life: ["can't be blank"],
      #          name: ["can't be blank"],
      #          photos: ["should have at least 3 item(s)"],
      #          tastes: ["should have at least 7 tastes"]
      #        }

      # assert {:ok, profile} =
      #          Accounts.update_photos(profile, %{photos: ["a", "b", "c"]}, validate?: true)

      # assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
      #          Accounts.onboard_profile(profile.user_id, %{})

      # assert errors_on(changeset) == %{
      #          birthdate: ["can't be blank"],
      #          first_date_idea: ["can't be blank"],
      #          gender: ["can't be blank"],
      #          height: ["can't be blank"],
      #          city: ["can't be blank"],
      #          most_important_in_life: ["can't be blank"],
      #          name: ["can't be blank"],
      #          interests: ["should have at least 2 item(s)"],
      #          tastes: ["should have at least 7 tastes"]
      #        }

      # assert {:ok, profile} =
      #          Accounts.update_general_profile_info(profile, %{
      #            gender: "M",
      #            birthdate: "2000-01-01",
      #            name: "Some Name",
      #            city: "Moscow",
      #            height: 150
      #          })

      # assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
      #          Accounts.onboard_profile(profile.user_id, %{})

      # assert errors_on(changeset) == %{
      #          first_date_idea: ["can't be blank"],
      #          most_important_in_life: ["can't be blank"],
      #          interests: ["should have at least 2 item(s)"],
      #          tastes: ["should have at least 7 tastes"]
      #        }

      # assert {:ok, profile} =
      #          Accounts.update_work_and_education_info(profile, %{
      #            university: "HSE",
      #            major: "Econ",
      #            occupation: "Accountant",
      #            job: "Unemployed"
      #          })

      # assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
      #          Accounts.onboard_profile(profile.user_id, %{})

      # assert errors_on(changeset) == %{
      #          first_date_idea: ["can't be blank"],
      #          most_important_in_life: ["can't be blank"],
      #          interests: ["should have at least 2 item(s)"],
      #          tastes: ["should have at least 7 tastes"]
      #        }

      # assert {:ok, profile} =
      #          Accounts.update_about_self_info(profile, %{
      #            most_important_in_life: "dunno",
      #            interests: ["running", "swimming", "walking", "crawling"],
      #            first_date_idea: "circus",
      #            free_form: "hm dunno"
      #          })

      # assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
      #          Accounts.onboard_profile(profile.user_id, %{})

      # assert errors_on(changeset) == %{
      #          tastes: ["should have at least 7 tastes"]
      #        }

      # assert {:ok, profile} =
      #          Accounts.update_tastes(profile, %{
      #            tastes: %{
      #              music: ["rice"],
      #              sports: ["bottles"],
      #              alcohol: "not really",
      #              smoking: "nah",
      #              books: ["lol no"],
      #              tv_shows: ["no"],
      #              currently_studying: ["nah"]
      #            }
      #          })

      # assert {:ok, %Profile{hidden?: false}} =
      #          Accounts.onboard_profile(profile.user_id, %{})

      # assert onboarded_at
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
