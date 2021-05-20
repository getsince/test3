defmodule T.Accounts.ProfileTest do
  use T.DataCase, async: true
  alias T.Accounts.Profile

  describe "essential_info_changeset/2" do
    test "gender and name are required" do
      changeset = Profile.essential_info_changeset(%Profile{}, %{}, validate_required?: true)

      assert errors_on(changeset) == %{
               gender: ["can't be blank"],
               name: ["can't be blank"],
               location: ["can't be blank"]
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
  end

  describe "changeset/3" do
    test "with valida info" do
      attrs = %{
        song: apple_music_song(),
        gender: "M",
        name: "Some Name",
        latitude: 50,
        longitude: 50
      }

      assert %Ecto.Changeset{valid?: true} =
               changeset = Profile.changeset(%Profile{}, attrs, validate_required?: true)

      assert errors_on(changeset) == %{}
    end
  end

  describe "song_changeset/2" do
    test "can nillify song" do
      %{profile: profile} = onboarded_user()
      assert profile.song

      assert %Ecto.Changeset{valid?: true} =
               changeset = Profile.changeset(profile, %{"song" => nil})

      refute apply_changes(changeset).song
    end
  end
end
