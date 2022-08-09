defmodule TWeb.FeedChannelTest do
  use TWeb.ChannelCase, async: true

  alias T.{Accounts, Matches}
  alias Matches.{Match, Interaction}

  setup do
    me = onboarded_user(location: moscow_location(), accept_genders: ["F", "N", "M"])

    {:ok,
     me: me, socket: connected_socket(me), socket_with_old_version: connected_socket(me, "6.9.0")}
  end

  describe "join" do
    test "with invalid topic", %{socket: socket} do
      assert {:error, %{"error" => "forbidden"}} = join(socket, "feed:" <> Ecto.UUID.generate())
    end

    test "shows private pages of matches", %{socket: socket, me: me} do
      stacy =
        onboarded_user(
          name: "Private Stacy",
          location: apple_location(),
          story: [
            %{"background" => %{"s3_key" => "public1"}, "labels" => [], "size" => [400, 100]},
            %{
              "background" => %{"s3_key" => "private"},
              "blurred" => %{"s3_key" => "blurred"},
              "labels" => [
                %{
                  "value" => "some private info",
                  "position" => [100, 100]
                }
              ],
              "size" => [100, 400]
            }
          ],
          gender: "F",
          accept_genders: ["M"]
        )

      insert(:match, user_id_1: me.id, user_id_2: stacy.id)

      assert {:ok, %{"matches" => [%{"profile" => %{story: [public, private]}}]}, _socket} =
               join(socket, "feed:" <> me.id)

      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["background", "labels", "private", "size"]
      assert %{"private" => true} = private
    end

    test "with feed if asked", %{socket: socket, me: me} do
      assert {:ok, %{}, _socket} = join(socket, "feed:" <> me.id)

      assert {:ok, %{"feed" => feed}, _socket} =
               join(socket, "feed:" <> me.id, %{"need_feed" => true})

      assert feed == []

      p = onboarded_user(story: [], name: "mate", location: apple_location(), gender: "F")

      assert {:ok, %{}, _socket} = join(socket, "feed:" <> me.id)

      assert {:ok, %{"feed" => feed}, _socket} =
               join(socket, "feed:" <> me.id, %{"need_feed" => true})

      assert feed == [
               %{
                 "profile" => %{
                   address: %{
                     "en_US" => %{
                       "city" => "Buenos Aires",
                       "country" => "Argentina",
                       "iso_country_code" => "AR",
                       "state" => "Autonomous City of Buenos Aires"
                     }
                   },
                   distance: 9510,
                   gender: "F",
                   name: "mate",
                   story: [],
                   user_id: p.id
                 }
               }
             ]
    end

    test "with matches", %{socket: socket, me: me} do
      [p1, p2, p3] = [
        onboarded_user(story: [], name: "mate-1", location: apple_location(), gender: "F"),
        onboarded_user(story: [], name: "mate-2", location: apple_location(), gender: "N"),
        onboarded_user(story: [], name: "mate-3", location: apple_location(), gender: "M")
      ]

      [m1, m2, m3] = [
        insert(:match, user_id_1: me.id, user_id_2: p1.id, inserted_at: ~N[2021-09-30 12:16:05]),
        insert(:match, user_id_1: me.id, user_id_2: p2.id, inserted_at: ~N[2021-09-30 12:16:06]),
        insert(:match, user_id_1: me.id, user_id_2: p3.id, inserted_at: ~N[2021-09-30 12:16:07])
      ]

      # first and second matches are seen
      :ok = Matches.mark_match_seen(me.id, m1.id)
      :ok = Matches.mark_match_seen(me.id, m2.id)

      # second match has one interaction
      {:ok, %Interaction{id: interaction_id_1}} =
        Matches.save_interaction(
          m2.id,
          me.id,
          %{
            "size" => [100, 100],
            "sticker" => %{"value" => "hey mama"}
          }
        )

      # third match had interaction exchanged
      {:ok, %Interaction{id: interaction_id_2}} =
        Matches.save_interaction(
          m3.id,
          me.id,
          %{
            "size" => [100, 100],
            "sticker" => %{"question" => "telegram", "answer" => "durov"}
          }
        )

      {:ok, %Interaction{id: interaction_id_3}} =
        Matches.save_interaction(
          m3.id,
          p3.id,
          %{
            "size" => [100, 100],
            "sticker" => %{"question" => "audio", "s3_key" => "abcd"}
          }
        )

      assert {:ok, %{"matches" => matches}, _socket} = join(socket, "feed:" <> me.id)

      assert matches == [
               %{
                 "id" => m3.id,
                 "profile" => %{
                   name: "mate-3",
                   story: [],
                   user_id: p3.id,
                   gender: "M",
                   distance: 9510,
                   address: %{
                     "en_US" => %{
                       "city" => "Buenos Aires",
                       "state" => "Autonomous City of Buenos Aires",
                       "country" => "Argentina",
                       "iso_country_code" => "AR"
                     }
                   }
                 },
                 "inserted_at" => ~U[2021-09-30 12:16:07Z],
                 "interactions" => [
                   %{
                     "from_user_id" => me.id,
                     "id" => interaction_id_2,
                     "inserted_at" => datetime(interaction_id_2),
                     "interaction" => %{
                       "size" => [100, 100],
                       "sticker" => %{
                         "answer" => "durov",
                         "question" => "telegram",
                         "url" => "https://t.me/durov"
                       }
                     },
                     "seen" => false
                   },
                   %{
                     "from_user_id" => p3.id,
                     "id" => interaction_id_3,
                     "inserted_at" => datetime(interaction_id_3),
                     "interaction" => %{
                       "size" => [100, 100],
                       "sticker" => %{
                         "question" => "audio",
                         "s3_key" => "abcd",
                         "url" => "https://d6666.cloudfront.net/abcd"
                       }
                     },
                     "seen" => false
                   }
                 ]
               },
               %{
                 "id" => m2.id,
                 "profile" => %{
                   name: "mate-2",
                   story: [],
                   user_id: p2.id,
                   gender: "N",
                   distance: 9510,
                   address: %{
                     "en_US" => %{
                       "city" => "Buenos Aires",
                       "state" => "Autonomous City of Buenos Aires",
                       "country" => "Argentina",
                       "iso_country_code" => "AR"
                     }
                   }
                 },
                 "inserted_at" => ~U[2021-09-30 12:16:06Z],
                 "expiration_date" => ~U[2021-10-01 12:16:06Z],
                 "seen" => true,
                 "interactions" => [
                   %{
                     "from_user_id" => me.id,
                     "id" => interaction_id_1,
                     "inserted_at" => datetime(interaction_id_1),
                     "interaction" => %{
                       "size" => [100, 100],
                       "sticker" => %{"value" => "hey mama"}
                     },
                     "seen" => false
                   }
                 ]
               },
               %{
                 "id" => m1.id,
                 "profile" => %{
                   name: "mate-1",
                   story: [],
                   user_id: p1.id,
                   gender: "F",
                   distance: 9510,
                   address: %{
                     "en_US" => %{
                       "city" => "Buenos Aires",
                       "state" => "Autonomous City of Buenos Aires",
                       "country" => "Argentina",
                       "iso_country_code" => "AR"
                     }
                   }
                 },
                 "inserted_at" => ~U[2021-09-30 12:16:05Z],
                 "expiration_date" => ~U[2021-10-01 12:16:05Z],
                 "seen" => true,
                 "interactions" => []
               }
             ]
    end

    test "with likes", %{socket: socket, me: me} do
      mate1 = onboarded_user(story: [], name: "mate-1", location: apple_location(), gender: "F")
      mate2 = onboarded_user(story: [], name: "mate-2", location: apple_location(), gender: "F")

      assert {:ok, %{like: %Matches.Like{}}} =
               Matches.like_user(mate1.id, me.id, default_location())

      assert {:ok, %{like: %Matches.Like{}}} =
               Matches.like_user(mate2.id, me.id, default_location())

      assert :ok = Matches.mark_like_seen(me.id, mate2.id)

      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id, %{"mode" => "normal"})

      assert reply == %{
               "likes" => [
                 %{
                   "profile" => %{
                     name: "mate-1",
                     story: [],
                     user_id: mate1.id,
                     gender: "F",
                     distance: 9510,
                     address: %{
                       "en_US" => %{
                         "city" => "Buenos Aires",
                         "state" => "Autonomous City of Buenos Aires",
                         "country" => "Argentina",
                         "iso_country_code" => "AR"
                       }
                     }
                   }
                 },
                 %{
                   "profile" => %{
                     name: "mate-2",
                     story: [],
                     user_id: mate2.id,
                     gender: "F",
                     distance: 9510,
                     address: %{
                       "en_US" => %{
                         "city" => "Buenos Aires",
                         "state" => "Autonomous City of Buenos Aires",
                         "country" => "Argentina",
                         "iso_country_code" => "AR"
                       }
                     }
                   },
                   "seen" => true
                 }
               ]
             }
    end

    test "with no news", %{socket: socket, me: me} do
      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)
      refute reply["news"]
    end

    test "without todos", %{socket: socket, me: me} do
      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id)
      refute reply["todos"]
    end

    test "with update todo", %{socket_with_old_version: socket_with_old_version, me: me} do
      assert {:ok, %{"todos" => todos}, _socket} = join(socket_with_old_version, "feed:" <> me.id)

      assert [_first_todos_item = %{story: story}] = todos
      assert [p1] = story

      assert %{"background" => %{"color" => _}, "labels" => labels, "size" => _} = p1

      assert labels
             |> Enum.any?(fn label ->
               label["action"] == "update_app"
             end)
    end

    test "with hidden_profile todo", %{socket: socket, me: me} do
      %T.Accounts.Profile{user_id: me.id}
      |> Ecto.Changeset.change(hidden?: true)
      |> T.Repo.update()

      assert {:ok, %{"todos" => todos}, _socket} = join(socket, "feed:" <> me.id)

      assert [_first_todos_item = %{story: story}] = todos
      assert [p1] = story

      assert %{"background" => %{"color" => _}, "labels" => labels, "size" => _} = p1

      assert labels
             |> Enum.any?(fn label ->
               label["action"] == "edit_story"
             end)
    end

    test "in onboarding mode without feed", %{socket: socket, me: me} do
      assert {:ok, reply, _socket} = join(socket, "feed:" <> me.id, %{"onboarding_mode" => true})

      assert reply == %{}
    end

    test "in onboarding mode with feed", %{socket: socket, me: me} do
      assert {:ok, reply, _socket} =
               join(socket, "feed:" <> me.id, %{"onboarding_mode" => true, "need_feed" => true})

      assert reply == %{"feed" => []}
    end
  end

  describe "more" do
    setup :joined

    test "with no data in db", %{socket: socket} do
      ref = push(socket, "more")
      assert_reply(ref, :ok, reply)
      assert reply == %{"feed" => []}
    end

    test "with users who haven't been online for a while", %{socket: socket} do
      long_ago = DateTime.add(DateTime.utc_now(), -62 * 24 * 60 * 60)

      for _ <- 1..3 do
        onboarded_user(
          location: apple_location(),
          accept_genders: ["F", "N", "M"],
          last_active: long_ago
        )
      end

      ref = push(socket, "more")
      assert_reply(ref, :ok, reply)
      assert reply == %{"feed" => []}
    end

    test "previously returned profiles are not returned, feed can be reset", %{socket: socket} do
      now = DateTime.utc_now()

      for i <- 1..5 do
        onboarded_user(
          name: "mate-#{i}",
          location: apple_location(),
          story: [%{"background" => %{"s3_key" => "test"}, "labels" => []}],
          gender: "M",
          accept_genders: ["M"],
          last_active: DateTime.add(now, -i)
        )
      end

      ref = push(socket, "more")
      assert_reply(ref, :ok, %{"feed" => feed0})

      initial_feed_ids =
        Enum.map(feed0, fn %{"profile" => profile} ->
          profile.user_id
        end)

      ref = push(socket, "more")

      assert_reply(ref, :ok, %{"feed" => feed1})

      for {p, _} <- feed1 do
        assert p.user_id not in initial_feed_ids
      end
    end

    test "with feed_limit", %{socket: socket, me: me} do
      p = onboarded_user(story: [], name: "mate", location: apple_location(), gender: "F")

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      insert(:feed_limit, user_id: me.id, timestamp: now |> DateTime.to_naive())

      ref = push(socket, "more")
      assert_reply(ref, :ok, %{"feed" => feed})

      feed_limit_expiration = now |> DateTime.add(T.Feeds.feed_limit_period())

      assert %{
               "feed_limit_expiration" => ^feed_limit_expiration,
               "story" => [%{"labels" => labels}]
             } = feed

      assert labels |> Enum.at(-1) == %{
               "alignment" => 1,
               "background_fill" => "#49BDB5",
               "corner_radius" => 0,
               "position" => [176.7486442601318, 506.01036228399676],
               "rotation" => 10.167247449849249,
               "text_color" => "#FFFFFF",
               "value" => "in the meantime, you can work \non your profile",
               "zoom" => 0.7091569071880537
             }

      insert(:match, user_id_1: me.id, user_id_2: p.id)

      ref = push(socket, "more")
      assert_reply(ref, :ok, %{"feed" => feed})

      assert %{
               "feed_limit_expiration" => ^feed_limit_expiration,
               "story" => [%{"labels" => labels}]
             } = feed

      assert labels |> Enum.at(-1) == %{
               "alignment" => 1,
               "background_fill" => "#6D42B1",
               "corner_radius" => 0,
               "position" => [
                 25.74864426013174,
                 484.3437057898561
               ],
               "rotation" => -10.167247449849249,
               "text_color" => "#FFFFFF",
               "value" => "in the meantime,\nyou can chat with matches",
               "zoom" => 0.7091569071880537
             }
    end
  end

  describe "like" do
    setup :joined

    setup do
      stacy =
        onboarded_user(
          name: "Private Stacy",
          location: apple_location(),
          story: [
            %{"background" => %{"s3_key" => "public1"}, "labels" => [], "size" => [400, 100]},
            %{
              "background" => %{"s3_key" => "private"},
              "blurred" => %{"s3_key" => "blurred"},
              "labels" => [
                %{
                  "value" => "some private info",
                  "position" => [100, 100]
                }
              ],
              "size" => [100, 400]
            }
          ],
          gender: "F",
          accept_genders: ["M"]
        )

      {:ok, mate: stacy}
    end

    setup :joined_mate

    test "when already liked by mate", ctx do
      %{
        me: me,
        socket: socket,
        mate: mate,
        mate_socket: mate_socket
      } = ctx

      # mate likes us
      ref = push(mate_socket, "like", %{"user_id" => me.id})
      assert_reply(ref, :ok, reply)
      assert reply == %{}

      # assert bump_likes works
      me_from_db = Repo.get!(T.Feeds.FeedProfile, me.id)
      assert me_from_db.like_ratio == 1.0

      # we got notified of like
      assert_push("invite", %{"profile" => %{story: [public, private] = story}} = invite)

      assert invite == %{
               "profile" => %{
                 gender: "F",
                 name: "Private Stacy",
                 story: story,
                 user_id: mate.id,
                 distance: 9510,
                 address: %{
                   "en_US" => %{
                     "city" => "Buenos Aires",
                     "state" => "Autonomous City of Buenos Aires",
                     "country" => "Argentina",
                     "iso_country_code" => "AR"
                   }
                 }
               }
             }

      # when we get notified of like, we are not showing private pages of the liker
      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["blurred", "private"]

      assert %{
               "blurred" => %{"s3_key" => "blurred", "proxy" => "https://" <> _},
               "private" => true
             } = private

      # now it's our turn
      ref = push(socket, "like", %{"user_id" => mate.id})

      assert_reply(ref, :ok, %{
        "match_id" => match_id,
        "expiration_date" => expiration_date,
        "profile" => %{story: [public, private]}
      })

      assert expiration_date
      assert is_binary(match_id)

      assert_push "matched", _payload

      # when we are matched, we can see private pages of the liker (now mate)
      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["background", "labels", "private", "size"]
      assert %{"private" => true} = private
    end

    test "when not yet liked by mate", ctx do
      %{
        me: me,
        socket: socket,
        mate: mate,
        mate_socket: mate_socket
      } = ctx

      # we like mate
      ref = push(socket, "like", %{"user_id" => mate.id})
      assert_reply(ref, :ok, reply)
      assert reply == %{}

      # now mate likes us
      ref = push(mate_socket, "like", %{"user_id" => me.id})
      assert_reply(ref, :ok, %{"match_id" => match_id})
      assert is_binary(match_id)

      assert_push "matched", %{"match" => match} = push

      now = DateTime.utc_now()
      expected_expiration_date = DateTime.add(now, Matches.match_ttl())
      assert expiration_date = match["expiration_date"]
      assert abs(DateTime.diff(expiration_date, expected_expiration_date)) <= 1

      assert %DateTime{} = inserted_at = match["inserted_at"]
      assert abs(DateTime.diff(now, inserted_at)) <= 1

      assert %{"match" => %{"profile" => %{story: [public, private] = story}}} = push

      assert push == %{
               "match" => %{
                 "id" => match_id,
                 "profile" => %{
                   name: "Private Stacy",
                   story: story,
                   user_id: mate.id,
                   gender: "F",
                   distance: 9510,
                   address: %{
                     "en_US" => %{
                       "city" => "Buenos Aires",
                       "state" => "Autonomous City of Buenos Aires",
                       "country" => "Argentina",
                       "iso_country_code" => "AR"
                     }
                   }
                 },
                 "expiration_date" => expiration_date,
                 "inserted_at" => inserted_at
               }
             }

      # when we are matched, we can see private pages
      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["background", "labels", "private", "size"]
      assert %{"private" => true} = private
    end

    test "seen-like", ctx do
      import Ecto.Query

      %{me: me, socket: socket, mate: mate} = ctx

      # mate likes us
      {:ok, _} = Matches.like_user(mate.id, me.id, default_location())

      # we see mate's like
      ref = push(socket, "seen-like", %{"user_id" => mate.id})
      assert_reply ref, :ok, _reply

      assert %Matches.Like{seen: true} =
               Matches.Like
               |> where(by_user_id: ^mate.id)
               |> where(user_id: ^me.id)
               |> Repo.one!()
    end
  end

  describe "seen-match" do
    setup :joined

    test "marks match as seen", %{me: me, socket: socket} do
      mate = onboarded_user()
      match = insert(:match, user_id_1: me.id, user_id_2: mate.id)

      ref = push(socket, "seen-match", %{"match_id" => match.id})
      assert_reply ref, :ok, _reply

      assert [%Match{seen: true}] = Matches.list_matches(me.id, default_location())
    end
  end

  describe "unmatch success" do
    setup :joined

    setup do
      {:ok, mate: onboarded_user(story: [], location: apple_location(), name: "mate")}
    end

    setup :joined_mate

    # match
    setup %{me: me, socket: socket, mate: mate, mate_socket: mate_socket} do
      # mate likes us
      ref = push(mate_socket, "like", %{"user_id" => me.id})
      assert_reply(ref, :ok, reply)
      assert reply == %{}

      # now it's our turn
      ref = push(socket, "like", %{"user_id" => mate.id})
      assert_reply(ref, :ok, %{"match_id" => match_id})

      {:ok, match_id: match_id}
    end

    test "with match_id", %{socket: socket, match_id: match_id} do
      ref = push(socket, "unmatch", %{"match_id" => match_id})
      assert_reply(ref, :ok, %{"unmatched?" => true})

      # mate gets unmatched message
      assert_push("unmatched", push)
      assert push == %{"match_id" => match_id}

      refute Repo.get(Match, match_id)
    end

    test "with user_id", %{socket: socket, mate: mate, match_id: match_id} do
      ref = push(socket, "unmatch", %{"user_id" => mate.id})
      assert_reply(ref, :ok, %{"unmatched?" => true})

      # mate gets unmatched message
      assert_push("unmatched", push)
      assert push == %{"match_id" => match_id}

      refute Repo.get(Match, match_id)
    end
  end

  describe "report without match" do
    setup :joined

    setup do
      {:ok, mate: onboarded_user(story: [], location: apple_location(), name: "mate")}
    end

    setup :joined_mate

    test "reports mate", %{socket: socket, mate: mate, me: me} do
      ref =
        push(socket, "report", %{
          "user_id" => mate.id,
          "reason" => "he don't believe in jesus"
        })

      assert_reply(ref, :ok, _reply)

      assert %Accounts.UserReport{} =
               report = Repo.get_by(Accounts.UserReport, from_user_id: me.id, on_user_id: mate.id)

      assert report.reason == "he don't believe in jesus"
    end
  end

  describe "report with match" do
    setup :joined

    setup %{me: me} do
      mate = onboarded_user(story: [], location: apple_location(), name: "mate")
      match = insert(:match, user_id_1: me.id, user_id_2: mate.id)
      {:ok, mate: mate, match: match}
    end

    setup :joined_mate

    test "reports mate and notifies of unmatch", %{
      socket: socket,
      match: match,
      mate: mate,
      me: me
    } do
      ref =
        push(socket, "report", %{
          "user_id" => mate.id,
          "reason" => "he don't believe in jesus"
        })

      assert_reply(ref, :ok, _reply)

      # mate gets unmatch message
      assert_push("unmatched", push)
      assert push == %{"match_id" => match.id}

      assert %Accounts.UserReport{} =
               report = Repo.get_by(Accounts.UserReport, from_user_id: me.id, on_user_id: mate.id)

      assert report.reason == "he don't believe in jesus"
    end
  end

  describe "interactions" do
    setup :joined

    test "send-interaction", %{me: me, socket: socket} do
      mate = onboarded_user()
      match = insert(:match, user_id_1: me.id, user_id_2: mate.id)

      # save normal interaction
      ref =
        push(socket, "send-interaction", %{
          "match_id" => match.id,
          "interaction" => %{"size" => [375, 667], "sticker" => %{"value" => "hello moto"}}
        })

      assert_reply ref, :ok, _reply
    end
  end

  describe "private stories" do
    setup :joined

    setup do
      now = DateTime.utc_now()

      stacy =
        onboarded_user(
          name: "Private Stacy",
          location: apple_location(),
          story: [
            %{"background" => %{"s3_key" => "public1"}, "labels" => [], "size" => [400, 100]},
            %{
              "background" => %{"s3_key" => "private"},
              "blurred" => %{"s3_key" => "blurred"},
              "labels" => [
                %{
                  "value" => "some private info",
                  "position" => [100, 100]
                }
              ],
              "size" => [100, 400]
            }
          ],
          gender: "F",
          accept_genders: ["M"],
          last_active: DateTime.add(now, -1)
        )

      {:ok, stacy: stacy}
    end

    test "more: private stories are blurred", %{socket: socket} do
      ref = push(socket, "more")
      assert_reply(ref, :ok, %{"feed" => feed})

      assert [%{"profile" => %{story: [public, private]}}] = feed

      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["blurred", "private"]

      assert %{
               "blurred" => %{
                 "s3_key" => "blurred",
                 "proxy" => "https://d1234.cloudfront.net/" <> _
               },
               "private" => true
             } = private
    end

    test "matched: private story becomes visible", %{me: me, stacy: stacy} do
      Matches.like_user(me.id, stacy.id, default_location())
      Matches.like_user(stacy.id, me.id, default_location())

      assert_push "matched", %{"match" => %{"profile" => %{story: [public, private]}}}
      assert Map.keys(public) == ["background", "labels", "size"]
      assert Map.keys(private) == ["background", "labels", "private", "size"]
      assert %{"private" => true} = private
    end
  end

  describe "feed_limit" do
    setup :joined
    alias T.Feeds

    test "feed_limit_reached", %{socket: socket, me: me} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      insert(:feed_limit, user_id: me.id, timestamp: now |> DateTime.to_naive())

      assert %Feeds.FeedLimit{reached: false} = Feeds.fetch_feed_limit(me.id)

      ref = push(socket, "reached-limit", %{"timestamp" => now})
      assert_reply(ref, :ok)

      assert %Feeds.FeedLimit{reached: true} = Feeds.fetch_feed_limit(me.id)
    end

    test "feed_limit_reset push, feed is returned", %{me: me} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      feed_limit_period_ago = DateTime.add(now, -Feeds.feed_limit_period() - 1)
      _limit = Feeds.insert_feed_limit(me.id, feed_limit_period_ago)

      # trigger scheduled FeedLimitResetJob
      assert %{success: 1} =
               Oban.drain_queue(queue: :default, with_safety: false, with_scheduled: true)

      assert_push "feed_limit_reset", %{"feed" => []}
    end
  end

  defp joined(%{socket: socket, me: me}) do
    assert {:ok, _reply, socket} = subscribe_and_join(socket, "feed:" <> me.id)

    {:ok, socket: socket}
  end

  defp joined_mate(%{mate: mate}) do
    socket = connected_socket(mate)
    {:ok, _reply, socket} = join(socket, "feed:" <> mate.id)
    {:ok, mate_socket: socket}
  end

  defp datetime(<<_::288>> = uuid) do
    datetime(Ecto.Bigflake.UUID.dump!(uuid))
  end

  defp datetime(<<unix::64, _rest::64>>) do
    unix |> DateTime.from_unix!(:millisecond) |> DateTime.truncate(:second)
  end
end
