defmodule Since.Accounts.ProfileTest do
  use T.DataCase, async: true
  alias Since.Accounts.Profile

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
      young = %Date{year: y - 18, month: m, day: d} |> Date.add(1)

      changeset =
        Profile.essential_info_changeset(%Profile{}, %{birthdate: Date.to_string(young)})

      assert errors_on(changeset).birthdate == ["too young"]

      changeset = Profile.essential_info_changeset(%Profile{}, %{birthdate: "1898-10-28"})

      assert errors_on(changeset).birthdate == ["too old"]
    end
  end

  describe "story_changeset/2" do
    test "success: passes on good story" do
      good_story = [
        %{
          "background" => %{"s3_key" => "public.jpg"},
          "labels" => [
            %{
              "question" => "telegram",
              # "answer" => "putin" works as well
              "value" => "putin",
              "position" => [24.0, 423.0]
            },
            %{
              "question" => "instagram",
              # "value" => "putin" works as well
              "answer" => "putin.rules__",
              "position" => [24.0, 123.0]
            },
            %{
              "value" => "Чувствую себя хорошо",
              "position" => [24.0, 306.0],
              "background_fill" => "#F97EB9",
              "rotation" => 20
            }
          ],
          "size" => [375, 667]
        },
        %{
          "background" => %{"s3_key" => "private.jpg"},
          "blurred" => %{"s3_key" => "private-blurred.jpg"},
          "labels" => [
            %{
              "question" => "whatsapp",
              # "answer" => "123454356" works as well
              "value" => "+001-(555)1234567",
              "position" => [24.0, 423.0]
            },
            %{
              "question" => "phone",
              # "value" => "putin" works as well
              "answer" => "+001-(555)1234567",
              "position" => [24.0, 123.0]
            },
            %{
              "question" => "email",
              "answer" => "putin@gov.uk",
              "position" => [74.0, 268.0]
            }
          ],
          "size" => [375, 667]
        }
      ]

      assert %Ecto.Changeset{valid?: true} =
               changeset = Profile.story_changeset(%Profile{}, %{"story" => good_story})

      %Profile{story: story, stickers: stickers} = apply_changes(changeset)

      assert story == [
               %{
                 "background" => %{"s3_key" => "public.jpg"},
                 "labels" => [
                   %{
                     "question" => "telegram",
                     "answer" => "putin",
                     "position" => [24.0, 423.0]
                   },
                   %{
                     "question" => "instagram",
                     "answer" => "putin.rules__",
                     "position" => [24.0, 123.0]
                   },
                   %{
                     "background_fill" => "#F97EB9",
                     "position" => [24.0, 306.0],
                     "rotation" => 20,
                     "value" => "Чувствую себя хорошо"
                   }
                 ],
                 "size" => [375, 667]
               },
               %{
                 "background" => %{"s3_key" => "private.jpg"},
                 "blurred" => %{"s3_key" => "private-blurred.jpg"},
                 "labels" => [
                   %{
                     "question" => "whatsapp",
                     "answer" => "15551234567",
                     "position" => [24.0, 423.0]
                   },
                   %{
                     "question" => "phone",
                     "answer" => "+15551234567",
                     "position" => [24.0, 123.0]
                   },
                   %{
                     "question" => "email",
                     "answer" => "putin@gov.uk",
                     "position" => [74.0, 268.0]
                   }
                 ],
                 "size" => [375, 667]
               }
             ]

      assert stickers == []
    end

    test "background with proxy but no s3 key is corrected" do
      story_with_proxied_bg = [
        %{
          "background" => %{
            "zoom" => 1.1315270791341807,
            "color" => "#6B4D32",
            "proxy" =>
              "https://d3r9yicn85nax9.cloudfront.net/cp17Xq0v0LFbrhGLfkq9YJ_VlAP9T22kq-of4ctP3DQ/fit/1200/0/sm/0/aHR0cHM6Ly9zaW5jZS13aGVuLWFyZS15b3UtaGFwcHkuczMuYW1hem9uYXdzLmNvbS8yODI5NWZkNS1lYjc4LTRlODctOTdjNy02MWI4NTdiYjVmMjQ",
            "position" => [-205.18224344932196, -444.03541915699407],
            "rotation" => 0
          },
          "size" => [400, 100]
        }
      ]

      assert %Ecto.Changeset{valid?: true} =
               changeset =
               Profile.story_changeset(%Profile{}, %{"story" => story_with_proxied_bg})

      %Profile{story: story} = apply_changes(changeset)

      assert story == [
               %{
                 "background" => %{
                   "zoom" => 1.1315270791341807,
                   "color" => "#6B4D32",
                   "s3_key" => "28295fd5-eb78-4e87-97c7-61b857bb5f24",
                   "position" => [-205.18224344932196, -444.03541915699407],
                   "rotation" => 0
                 },
                 "size" => [400, 100]
               }
             ]
    end

    test "telegram validation" do
      attrs = fn label ->
        %{
          "story" => [
            %{
              "background" => %{"color" => "#FFFFFF"},
              "labels" => [label],
              "size" => [375, 667]
            }
          ]
        }
      end

      # valid value

      valid_value = %{"question" => "telegram", "value" => " @PuTiN123 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_value))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "telegram", "answer" => "putin123"}],
                 "size" => [375, 667]
               }
             ]

      # valid answer

      valid_answer = %{"question" => "telegram", "answer" => " @PuTiN123 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_answer))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "telegram", "answer" => "putin123"}],
                 "size" => [375, 667]
               }
             ]

      # invalid format

      invalid_format = %{"question" => "telegram", "answer" => " @PuTiN  123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["telegram username has invalid format"]}

      # too short

      too_short = %{"question" => "telegram", "answer" => " @PuTi"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(too_short))

      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: ["telegram username should be at least 5 character(s)"]
             }

      # too long

      too_long = %{
        "question" => "telegram",
        "answer" => " PuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTi"
      }

      changeset = Profile.story_changeset(%Profile{}, attrs.(too_long))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: ["telegram username should be at most 32 character(s)"]
             }
    end

    test "instagram validation" do
      attrs = fn label ->
        %{
          "story" => [
            %{
              "background" => %{"color" => "#FFFFFF"},
              "labels" => [label],
              "size" => [375, 667]
            }
          ]
        }
      end

      # valid value

      valid_value = %{"question" => "instagram", "value" => " @PuTiN.123 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_value))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "instagram", "answer" => "putin.123"}],
                 "size" => [375, 667]
               }
             ]

      # valid answer

      valid_answer = %{"question" => "instagram", "answer" => " @PuTiN____123 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_answer))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "instagram", "answer" => "putin____123"}],
                 "size" => [375, 667]
               }
             ]

      # invalid formats

      invalid_format = %{"question" => "instagram", "answer" => " @PuTiN  123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["instagram username has invalid format"]}

      invalid_format = %{"question" => "instagram", "answer" => " @PuTiN..123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["instagram username has invalid format"]}

      # too long

      too_long = %{
        "question" => "instagram",
        "answer" => " PuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTi"
      }

      changeset = Profile.story_changeset(%Profile{}, attrs.(too_long))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: ["instagram username should be at most 30 character(s)"]
             }
    end

    test "snapchat validation" do
      attrs = fn label ->
        %{
          "story" => [
            %{
              "background" => %{"color" => "#FFFFFF"},
              "labels" => [label],
              "size" => [375, 667]
            }
          ]
        }
      end

      # valid value

      valid_value = %{"question" => "snapchat", "value" => " @PuTiN.123 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_value))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "snapchat", "answer" => "putin.123"}],
                 "size" => [375, 667]
               }
             ]

      # valid answer

      valid_answer = %{"question" => "snapchat", "answer" => " @PuTiN____123 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_answer))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "snapchat", "answer" => "putin____123"}],
                 "size" => [375, 667]
               }
             ]

      # invalid formats

      invalid_format = %{"question" => "snapchat", "answer" => " @PuTiN  123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["snapchat username has invalid format"]}

      invalid_format = %{"question" => "snapchat", "answer" => " @PuTiN$$123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["snapchat username has invalid format"]}

      # too short

      too_short = %{"question" => "snapchat", "answer" => " @P"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(too_short))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: [
                 "snapchat username should be at least 3 character(s)"
               ]
             }

      # too long

      too_long = %{
        "question" => "snapchat",
        "answer" => " PuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTi"
      }

      changeset = Profile.story_changeset(%Profile{}, attrs.(too_long))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: ["snapchat username should be at most 15 character(s)"]
             }
    end

    test "twitter validation" do
      attrs = fn label ->
        %{
          "story" => [
            %{
              "background" => %{"color" => "#FFFFFF"},
              "labels" => [label],
              "size" => [375, 667]
            }
          ]
        }
      end

      # valid value

      valid_value = %{"question" => "twitter", "value" => " @PuTiN_123 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_value))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "twitter", "answer" => "putin_123"}],
                 "size" => [375, 667]
               }
             ]

      # valid answer

      valid_answer = %{"question" => "twitter", "answer" => " @PuTiN____123 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_answer))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "twitter", "answer" => "putin____123"}],
                 "size" => [375, 667]
               }
             ]

      # invalid formats

      invalid_format = %{"question" => "twitter", "answer" => " @PuTiN  123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["twitter username has invalid format"]}

      invalid_format = %{"question" => "twitter", "answer" => " @PuTiN$$123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["twitter username has invalid format"]}

      # too short

      too_short = %{"question" => "twitter", "answer" => " @"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(too_short))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: [
                 "twitter username should be at least 1 character(s)",
                 "twitter username has invalid format"
               ]
             }

      # too long

      too_long = %{
        "question" => "twitter",
        "answer" => " PuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTiPuTi"
      }

      changeset = Profile.story_changeset(%Profile{}, attrs.(too_long))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: ["twitter username should be at most 15 character(s)"]
             }
    end

    test "messenger validation" do
      attrs = fn label ->
        %{
          "story" => [
            %{
              "background" => %{"color" => "#FFFFFF"},
              "labels" => [label],
              "size" => [375, 667]
            }
          ]
        }
      end

      # valid value

      valid_value = %{"question" => "messenger", "value" => " @PuTiN_123 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_value))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "messenger", "answer" => "putin_123"}],
                 "size" => [375, 667]
               }
             ]

      # valid answer

      valid_answer = %{"question" => "messenger", "answer" => " @PuTiN____123 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_answer))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "messenger", "answer" => "putin____123"}],
                 "size" => [375, 667]
               }
             ]

      # invalid formats

      invalid_format = %{"question" => "messenger", "answer" => " @PuTiN  123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["messenger username has invalid format"]}

      invalid_format = %{"question" => "messenger", "answer" => " @PuTiN$$123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["messenger username has invalid format"]}

      # too short

      too_short = %{"question" => "messenger", "answer" => " @Pup"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(too_short))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: [
                 "messenger username should be at least 5 character(s)"
               ]
             }
    end

    test "whatsapp validation" do
      attrs = fn label ->
        %{
          "story" => [
            %{
              "background" => %{"color" => "#FFFFFF"},
              "labels" => [label],
              "size" => [375, 667]
            }
          ]
        }
      end

      # valid value

      valid_value = %{"question" => "whatsapp", "value" => " +001-(555)1234567 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_value))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "whatsapp", "answer" => "15551234567"}],
                 "size" => [375, 667]
               }
             ]

      # valid answer

      valid_answer = %{"question" => "whatsapp", "answer" => " +7 (916) 911 23 23 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_answer))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "whatsapp", "answer" => "79169112323"}],
                 "size" => [375, 667]
               }
             ]

      # invalid format

      invalid_format = %{"question" => "whatsapp", "answer" => " @PuTiN  123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["whatsapp phone number has invalid format"]}

      # too short

      too_short = %{"question" => "whatsapp", "answer" => "+777"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(too_short))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: ["whatsapp phone number should be at least 4 character(s)"]
             }

      # too long

      too_long = %{
        "question" => "whatsapp",
        "answer" => " +88888888888888888"
      }

      changeset = Profile.story_changeset(%Profile{}, attrs.(too_long))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: ["whatsapp phone number should be at most 15 character(s)"]
             }
    end

    test "signal validation" do
      attrs = fn label ->
        %{
          "story" => [
            %{
              "background" => %{"color" => "#FFFFFF"},
              "labels" => [label],
              "size" => [375, 667]
            }
          ]
        }
      end

      # valid value

      valid_value = %{"question" => "signal", "value" => " +001-(555)1234567 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_value))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "signal", "answer" => "+15551234567"}],
                 "size" => [375, 667]
               }
             ]

      # valid answer

      valid_answer = %{"question" => "signal", "answer" => " +7 (916) 911 23 23 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_answer))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "signal", "answer" => "+79169112323"}],
                 "size" => [375, 667]
               }
             ]

      # invalid format

      invalid_format = %{"question" => "signal", "answer" => " @PuTiN  123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["signal phone number has invalid format"]}

      # too short

      too_short = %{"question" => "signal", "answer" => "+777"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(too_short))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: ["signal phone number should be at least 4 character(s)"]
             }

      # too long

      too_long = %{
        "question" => "signal",
        "answer" => " +88888888888888888"
      }

      changeset = Profile.story_changeset(%Profile{}, attrs.(too_long))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: ["signal phone number should be at most 15 character(s)"]
             }
    end

    test "phone validation" do
      attrs = fn label ->
        %{
          "story" => [
            %{
              "background" => %{"color" => "#FFFFFF"},
              "labels" => [label],
              "size" => [375, 667]
            }
          ]
        }
      end

      # valid value

      valid_value = %{"question" => "phone", "value" => " +001-(555)1234567 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_value))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "phone", "answer" => "+15551234567"}],
                 "size" => [375, 667]
               }
             ]

      # valid answer

      valid_answer = %{"question" => "phone", "answer" => " +7 (916) 911 23 23 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_answer))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "phone", "answer" => "+79169112323"}],
                 "size" => [375, 667]
               }
             ]

      # invalid format

      invalid_format = %{"question" => "phone", "answer" => " @PuTiN  123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["phone number has invalid format"]}

      # too short

      too_short = %{"question" => "phone", "answer" => "+777"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(too_short))
      refute changeset.valid?

      assert errors_on(changeset) == %{story: ["phone number should be at least 4 character(s)"]}

      # too long

      too_long = %{
        "question" => "whatsapp",
        "answer" => " +88888888888888888"
      }

      changeset = Profile.story_changeset(%Profile{}, attrs.(too_long))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: ["whatsapp phone number should be at most 15 character(s)"]
             }
    end

    test "imessage phone validation" do
      attrs = fn label ->
        %{
          "story" => [
            %{
              "background" => %{"color" => "#FFFFFF"},
              "labels" => [label],
              "size" => [375, 667]
            }
          ]
        }
      end

      # valid value

      valid_value = %{"question" => "imessage", "value" => " +001-(555)1234567 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_value))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "imessage", "answer" => "+15551234567"}],
                 "size" => [375, 667]
               }
             ]

      # valid answer

      valid_answer = %{"question" => "imessage", "answer" => " +7 (916) 911 23 23 "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_answer))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "imessage", "answer" => "+79169112323"}],
                 "size" => [375, 667]
               }
             ]

      # invalid format

      invalid_format = %{"question" => "imessage", "answer" => " @PuTiN  123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["imessage email address has invalid format"]}

      # too short

      too_short = %{"question" => "imessage", "answer" => "+777"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(too_short))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: ["imessage phone number should be at least 4 character(s)"]
             }

      # too long

      too_long = %{
        "question" => "imessage",
        "answer" => " +88888888888888888"
      }

      changeset = Profile.story_changeset(%Profile{}, attrs.(too_long))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: ["imessage phone number should be at most 15 character(s)"]
             }
    end

    test "imessage email validation" do
      attrs = fn label ->
        %{
          "story" => [
            %{
              "background" => %{"color" => "#FFFFFF"},
              "labels" => [label],
              "size" => [375, 667]
            }
          ]
        }
      end

      # valid value

      valid_value = %{"question" => "imessage", "value" => " PUTIN@gov.UK "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_value))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "imessage", "answer" => "putin@gov.uk"}],
                 "size" => [375, 667]
               }
             ]

      # valid answer

      valid_answer = %{"question" => "imessage", "answer" => " PUTIN@gov.UK "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_answer))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "imessage", "answer" => "putin@gov.uk"}],
                 "size" => [375, 667]
               }
             ]

      # invalid format

      invalid_format = %{"question" => "imessage", "answer" => " PuTiN  123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["imessage phone number has invalid format"]}

      # too short

      too_short = %{"question" => "imessage", "answer" => "a@a."}
      changeset = Profile.story_changeset(%Profile{}, attrs.(too_short))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: [
                 "imessage email address has invalid format",
                 "imessage email address should be at least 5 character(s)"
               ]
             }

      # too long

      too_long = %{
        "question" => "imessage",
        "answer" => String.duplicate("putin-rules", 10) <> "@gmail.com"
      }

      changeset = Profile.story_changeset(%Profile{}, attrs.(too_long))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: ["imessage email address should be at most 60 character(s)"]
             }
    end

    test "email validation" do
      attrs = fn label ->
        %{
          "story" => [
            %{
              "background" => %{"color" => "#FFFFFF"},
              "labels" => [label],
              "size" => [375, 667]
            }
          ]
        }
      end

      # valid value

      valid_value = %{"question" => "email", "value" => " PUTIN@gov.UK "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_value))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "email", "answer" => "putin@gov.uk"}],
                 "size" => [375, 667]
               }
             ]

      # valid answer

      valid_answer = %{"question" => "email", "answer" => " PUTIN@gov.UK "}
      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_answer))
      assert changeset.valid?

      assert apply_changes(changeset).story == [
               %{
                 "background" => %{"color" => "#FFFFFF"},
                 "labels" => [%{"question" => "email", "answer" => "putin@gov.uk"}],
                 "size" => [375, 667]
               }
             ]

      # invalid format

      invalid_format = %{"question" => "email", "answer" => " PuTiN  123"}
      changeset = Profile.story_changeset(%Profile{}, attrs.(invalid_format))

      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["email address has invalid format"]}

      # too short

      too_short = %{"question" => "email", "answer" => "a@a."}
      changeset = Profile.story_changeset(%Profile{}, attrs.(too_short))
      refute changeset.valid?

      assert errors_on(changeset) == %{
               story: [
                 "email address has invalid format",
                 "email address should be at least 5 character(s)"
               ]
             }

      # too long

      too_long = %{
        "question" => "email",
        "answer" => String.duplicate("putin-rules", 10) <> "@gmail.com"
      }

      changeset = Profile.story_changeset(%Profile{}, attrs.(too_long))
      refute changeset.valid?
      assert errors_on(changeset) == %{story: ["email address should be at most 60 character(s)"]}
    end

    test "stickers are updated" do
      attrs = fn labels ->
        %{
          "story" => [
            %{
              "background" => %{"color" => "#FFFFFF"},
              "labels" => labels,
              "size" => [375, 667]
            }
          ]
        }
      end

      # multiple stickers

      valid_value = [
        %{"question" => "interests", "answer" => "sex"},
        %{"question" => "sports", "answer" => "domino"}
      ]

      changeset = Profile.story_changeset(%Profile{}, attrs.(valid_value))
      assert changeset.valid?

      assert apply_changes(changeset).stickers == ["domino", "sex"]

      # contact, birthdate, normal sticker

      labels = [
        %{"question" => "telegram", "answer" => "loxxxx"},
        %{"question" => "birthdate", "answer" => "1994-06-21T14:46:37Z"},
        %{"question" => "food", "answer" => "bread"}
      ]

      changeset = Profile.story_changeset(%Profile{}, attrs.(labels))
      assert changeset.valid?

      assert apply_changes(changeset).stickers == ["bread"]
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
