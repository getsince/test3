defmodule T.Accounts.ProfileTest do
  use T.DataCase, async: true
  alias T.Accounts.Profile

  describe "photos_changeset/2" do
    test "need at least 3 and at most 6 photos" do
      changeset = Profile.photos_changeset(%Profile{}, %{}, validate_required?: true)
      assert errors_on(changeset).photos == ["can't be blank"]

      changeset =
        Profile.photos_changeset(%Profile{}, %{photos: ["a", "b", "c"]}, validate_required?: true)

      assert errors_on(changeset).photos == ["should have 4 item(s)"]

      changeset =
        Profile.photos_changeset(%Profile{}, %{photos: ["a", "b", "c", "d"]},
          validate_required?: true
        )

      refute errors_on(changeset)[:photos]

      changeset =
        Profile.photos_changeset(%Profile{}, %{photos: ["a", "b", "c", "d", "e", "f", "g"]},
          validate_required?: true
        )

      assert errors_on(changeset).photos == ["should have 4 item(s)"]
    end
  end

  describe "general_info_changeset/2" do
    test "all fields required" do
      changeset = Profile.general_info_changeset(%Profile{}, %{}, validate_required?: true)

      assert errors_on(changeset) == %{
               birthdate: ["can't be blank"],
               gender: ["can't be blank"],
               height: ["can't be blank"],
               city: ["can't be blank"],
               name: ["can't be blank"]
             }
    end

    test "name needs to be 3 chars at least" do
      changeset = Profile.general_info_changeset(%Profile{}, %{name: "a"})
      assert errors_on(changeset).name == ["should be at least 3 character(s)"]

      assert changeset = Profile.general_info_changeset(%Profile{}, %{name: "aaa"})
      refute errors_on(changeset)[:name]
    end

    test "name is 100 chars at most" do
      changeset = Profile.general_info_changeset(%Profile{}, %{name: String.duplicate("a", 101)})
      assert errors_on(changeset).name == ["should be at most 100 character(s)"]

      changeset = Profile.general_info_changeset(%Profile{}, %{name: String.duplicate("a", 100)})
      refute errors_on(changeset)[:name]
    end

    test "gender is either M or F" do
      changeset = Profile.general_info_changeset(%Profile{}, %{gender: "M"})
      refute errors_on(changeset)[:gender]

      changeset = Profile.general_info_changeset(%Profile{}, %{gender: "F"})
      refute errors_on(changeset)[:gender]

      changeset = Profile.general_info_changeset(%Profile{}, %{gender: "fw"})
      assert errors_on(changeset).gender == ["is invalid"]
    end

    test "height is at least 1" do
      changeset = Profile.general_info_changeset(%Profile{}, %{height: 0})
      assert errors_on(changeset).height == ["must be greater than 0"]

      assert changeset = Profile.general_info_changeset(%Profile{}, %{height: 1})
      refute errors_on(changeset)[:height]
    end

    test "height is at most 240" do
      changeset = Profile.general_info_changeset(%Profile{}, %{height: 241})
      assert errors_on(changeset).height == ["must be less than or equal to 240"]

      changeset = Profile.general_info_changeset(%Profile{}, %{height: 240})
      refute errors_on(changeset)[:height]
    end

    test "birthdate is after 1920-01-01" do
      changeset = Profile.general_info_changeset(%Profile{}, %{birthdate: "1919-01-01"})
      assert errors_on(changeset).birthdate == ["too old"]

      changeset = Profile.general_info_changeset(%Profile{}, %{birthdate: "1920-01-01"})
      refute errors_on(changeset)[:birthdate]

      changeset = Profile.general_info_changeset(%Profile{}, %{birthdate: "1995-01-01"})
      refute errors_on(changeset)[:birthdate]
    end

    test "birthdate is more than 16 years ago" do
      changeset = Profile.general_info_changeset(%Profile{}, %{birthdate: "2015-01-01"})
      assert errors_on(changeset).birthdate == ["too young"]

      changeset = Profile.general_info_changeset(%Profile{}, %{birthdate: "2000-01-01"})
      refute errors_on(changeset)[:birthdate]
    end
  end

  describe "work_and_education_changeset/2" do
    test "no attrs are required" do
      assert %Ecto.Changeset{valid?: true} =
               changeset = Profile.work_and_education_changeset(%Profile{}, %{})

      assert errors_on(changeset) == %{}
    end

    test "occupation should be less than 100 chars" do
      changeset =
        Profile.work_and_education_changeset(%Profile{}, %{occupation: String.duplicate("a", 100)})

      refute errors_on(changeset)[:occupation]

      changeset =
        Profile.work_and_education_changeset(%Profile{}, %{occupation: String.duplicate("a", 101)})

      assert errors_on(changeset).occupation == ["should be at most 100 character(s)"]
    end

    test "job should be less than 100 chars" do
      changeset =
        Profile.work_and_education_changeset(%Profile{}, %{job: String.duplicate("a", 100)})

      refute errors_on(changeset)[:job]

      changeset =
        Profile.work_and_education_changeset(%Profile{}, %{job: String.duplicate("a", 101)})

      assert errors_on(changeset).job == ["should be at most 100 character(s)"]
    end

    test "university should be less than 100 chars" do
      changeset =
        Profile.work_and_education_changeset(%Profile{}, %{university: String.duplicate("a", 100)})

      refute errors_on(changeset)[:university]

      changeset =
        Profile.work_and_education_changeset(%Profile{}, %{university: String.duplicate("a", 201)})

      assert errors_on(changeset).university == ["should be at most 200 character(s)"]
    end

    test "major should be less than 100 chars" do
      changeset =
        Profile.work_and_education_changeset(%Profile{}, %{major: String.duplicate("a", 100)})

      refute errors_on(changeset)[:major]

      changeset =
        Profile.work_and_education_changeset(%Profile{}, %{major: String.duplicate("a", 101)})

      assert errors_on(changeset).major == ["should be at most 100 character(s)"]
    end
  end

  describe "about_self_changeset/2" do
    test "all fields except for free_form are required" do
      assert %Ecto.Changeset{valid?: false} =
               changeset = Profile.about_self_changeset(%Profile{}, %{}, validate_required?: true)

      assert errors_on(changeset) == %{
               first_date_idea: ["can't be blank"],
               most_important_in_life: ["can't be blank"],
               interests: ["can't be blank"]
             }
    end

    test "needs at least two interests and at most five" do
      changeset = Profile.about_self_changeset(%Profile{}, %{interests: []})
      assert errors_on(changeset).interests == ["should have at least 2 item(s)"]

      changeset = Profile.about_self_changeset(%Profile{}, %{interests: ["a", "b"]})
      refute errors_on(changeset)[:interests]

      changeset =
        Profile.about_self_changeset(%Profile{}, %{interests: ["a", "b", "c", "d", "e"]})

      refute errors_on(changeset)[:interests]

      changeset =
        Profile.about_self_changeset(%Profile{}, %{interests: ["a", "b", "c", "d", "e", "f"]})

      assert errors_on(changeset).interests == ["should have at most 5 item(s)"]
    end

    test "most_important_in_life is at most 100 chars" do
      changeset =
        Profile.about_self_changeset(%Profile{}, %{
          most_important_in_life: String.duplicate("a", 100)
        })

      refute errors_on(changeset)[:most_important_in_life]

      changeset =
        Profile.about_self_changeset(%Profile{}, %{
          most_important_in_life: String.duplicate("a", 101)
        })

      assert errors_on(changeset).most_important_in_life == ["should be at most 100 character(s)"]
    end

    test "first_date_idea is at most 100 chars" do
      changeset =
        Profile.about_self_changeset(%Profile{}, %{
          first_date_idea: String.duplicate("a", 100)
        })

      refute errors_on(changeset)[:first_date_idea]

      changeset =
        Profile.about_self_changeset(%Profile{}, %{
          first_date_idea: String.duplicate("a", 101)
        })

      assert errors_on(changeset).first_date_idea == ["should be at most 100 character(s)"]
    end

    test "free_form is at most 1000 chars" do
      changeset =
        Profile.about_self_changeset(%Profile{}, %{
          free_form: String.duplicate("a", 1000)
        })

      refute errors_on(changeset)[:free_form]

      changeset =
        Profile.about_self_changeset(%Profile{}, %{
          free_form: String.duplicate("a", 1001)
        })

      assert errors_on(changeset).free_form == ["should be at most 1000 character(s)"]
    end
  end

  describe "tastes_changeset/2" do
    test "needs at least seven tastes" do
      assert %Ecto.Changeset{valid?: false} =
               changeset = Profile.tastes_changeset(%Profile{}, %{}, validate_required?: true)

      #  TODO
      assert errors_on(changeset) == %{tastes: ["can't be blank"]}
    end

    @array_tastes [
      :music,
      :sports,
      :books,
      :currently_studying,
      :tv_shows,
      :languages,
      :musical_instruments,
      :movies,
      :social_networks,
      :cuisines,
      :pets
    ]

    for taste <- @array_tastes do
      @tag skip: true
      test "need at least 1 and at most 5 items in #{taste}" do
        changeset = Profile.tastes_changeset(%Profile{}, %{tastes: [%{unquote(taste) => []}]})
        assert errors_on(changeset)[unquote(taste)] == ["should have at least 1 item(s)"]

        changeset = Profile.tastes_changeset(%Profile{}, %{unquote(taste) => ["a"]})
        refute errors_on(changeset)[unquote(taste)]

        changeset =
          Profile.tastes_changeset(%Profile{}, %{unquote(taste) => ["a", "b", "c", "d", "e"]})

        refute errors_on(changeset)[unquote(taste)]

        changeset =
          Profile.tastes_changeset(%Profile{}, %{unquote(taste) => ["a", "b", "c", "d", "e", "f"]})

        assert errors_on(changeset)[unquote(taste)] == ["should have at most 5 item(s)"]
      end
    end

    @tag skip: true
    test "alcohol is at most 100 chars" do
      changeset =
        Profile.tastes_changeset(%Profile{}, %{
          alcohol: String.duplicate("a", 100)
        })

      refute errors_on(changeset)[:alcohol]

      changeset =
        Profile.tastes_changeset(%Profile{}, %{
          alcohol: String.duplicate("a", 101)
        })

      assert errors_on(changeset).alcohol == ["should be at most 100 character(s)"]
    end

    @tag skip: true
    test "smoking is at most 100 chars" do
      changeset =
        Profile.tastes_changeset(%Profile{}, %{
          smoking: String.duplicate("a", 100)
        })

      refute errors_on(changeset)[:smoking]

      changeset =
        Profile.tastes_changeset(%Profile{}, %{
          smoking: String.duplicate("a", 101)
        })

      assert errors_on(changeset).smoking == ["should be at most 100 character(s)"]
    end
  end

  describe "changeset/3" do
    test "with valida info" do
      attrs = %{
        photos: ["file1.jpg", "file2.jpg", "file3.jpg", "file4.jpg"],
        song: apple_music_song(),
        gender: "M",
        birthdate: ~D[2000-01-01],
        name: "Some Name",
        city: "Moscow",
        height: 150,
        university: "HSE",
        major: "Econ",
        occupation: "Accountant",
        job: "Unemployed",
        most_important_in_life: "dunno",
        interests: ["running", "swimming", "walking", "crawling"],
        first_date_idea: "circus",
        free_form: "hm dunno",
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

      assert %Ecto.Changeset{valid?: true} =
               changeset = Profile.changeset(%Profile{}, attrs, validate_required?: true)

      assert errors_on(changeset) == %{}
    end
  end
end
