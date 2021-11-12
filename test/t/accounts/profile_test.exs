defmodule T.Accounts.ProfileTest do
  use T.DataCase, async: true
  alias T.Accounts.Profile

  describe "essential_info_changeset/2" do
    test "gender, name, birthdate, location and gender_preferences are required" do
      changeset = Profile.essential_info_changeset(%Profile{}, %{}, validate_required?: true)

      assert errors_on(changeset) == %{
               gender: ["can't be blank"],
               name: ["can't be blank"],
               birthdate: ["can't be blank"],
               location: ["can't be blank"],
               gender_preference: ["can't be blank"]
             }
    end

    test "name is required, blanks are not accepted" do
      changeset =
        Profile.essential_info_changeset(%Profile{}, %{name: ""}, validate_required?: true)

      assert errors_on(changeset).name == ["can't be blank"]

      changeset = Profile.essential_info_changeset(%Profile{}, %{name: "a"})
      assert errors_on(changeset) == %{}

      assert changeset = Profile.essential_info_changeset(%Profile{}, %{name: "aaa"})
      assert errors_on(changeset) == %{}
    end

    test "name is 100 chars at most" do
      changeset =
        Profile.essential_info_changeset(%Profile{}, %{name: String.duplicate("a", 101)})

      assert errors_on(changeset).name == ["should be at most 100 character(s)"]

      changeset =
        Profile.essential_info_changeset(%Profile{}, %{name: String.duplicate("a", 100)})

      refute errors_on(changeset)[:name]
    end

    test "gender is either M or F" do
      changeset = Profile.essential_info_changeset(%Profile{}, %{gender: "M"})
      refute errors_on(changeset)[:gender]

      changeset = Profile.essential_info_changeset(%Profile{}, %{gender: "F"})
      refute errors_on(changeset)[:gender]

      changeset = Profile.essential_info_changeset(%Profile{}, %{gender: "fw"})
      assert errors_on(changeset).gender == ["is invalid"]
    end

    test "birthdate is required, birthdate is Date 18-100 years ago" do
      changeset =
        Profile.essential_info_changeset(%Profile{}, %{birthdate: ""}, validate_required?: true)

      assert errors_on(changeset).birthdate == ["can't be blank"]

      changeset = Profile.essential_info_changeset(%Profile{}, %{birthdate: "1998-10-28"})
      refute errors_on(changeset)[:birthdate]

      changeset = Profile.essential_info_changeset(%Profile{}, %{birthdate: "a"})
      assert errors_on(changeset).birthdate == ["is invalid"]

      changeset =
        Profile.essential_info_changeset(%Profile{}, %{birthdate: "1998-10-28 13:57:36"})

      refute errors_on(changeset)[:birthdate]

      changeset =
        Profile.essential_info_changeset(%Profile{}, %{
          birthdate: Date.to_string(DateTime.utc_now())
        })

      assert errors_on(changeset).birthdate == ["too young"]

      %{year: y, month: m, day: d} = DateTime.utc_now()
      young = %Date{year: y - 18, month: m, day: d + 1}

      changeset =
        Profile.essential_info_changeset(%Profile{}, %{birthdate: Date.to_string(young)})

      assert errors_on(changeset).birthdate == ["too young"]

      changeset = Profile.essential_info_changeset(%Profile{}, %{birthdate: "1898-10-28"})

      assert errors_on(changeset).birthdate == ["too old"]
    end
  end

  describe "changeset/3" do
    test "with valid info" do
      attrs = %{
        gender: "M",
        name: "Some Name",
        birthdate: "1998-10-28",
        latitude: 50,
        longitude: 50,
        gender_preference: ["F"],
        distance: nil,
        min_age: nil,
        max_age: nil
      }

      assert %Ecto.Changeset{valid?: true} =
               changeset = Profile.changeset(%Profile{}, attrs, validate_required?: true)

      assert errors_on(changeset) == %{}
    end
  end
end
