defmodule T.Matches.InteractionsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.Matches
  alias T.Matches.{Interaction, MatchEvent}

  describe "save_interaction/3 for invalid match" do
    setup [:with_profiles]

    @interaction %{"size" => [375, 667], "sticker" => %{"value" => "you can get a few more "}}

    test "with non-existent match", %{profiles: [p1, _]} do
      match = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Matches.save_interaction(match, p1.user_id, @interaction)
      end
    end

    test "with match we are not part of", %{profiles: [p1, p2]} do
      p3 = insert(:profile, hidden?: false)
      match = insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)

      assert_raise Ecto.NoResultsError, fn ->
        Matches.save_interaction(match.id, p3.user_id, @interaction)
      end

      assert MatchEvent |> T.Repo.all() == []
    end
  end

  describe "save_interaction/3" do
    setup [:with_profiles, :with_match]

    test "with empty interaction", %{profiles: [p1, _], match: match} do
      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Matches.save_interaction(match.id, p1.user_id, %{"" => ""})

      assert errors_on(changeset) == %{interaction: ["unrecognized interaction type"]}
    end

    test "with unsupported interaction", %{profiles: [p1, _], match: match} do
      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Matches.save_interaction(match.id, p1.user_id, %{
                 "size" => [375, 667],
                 "sticker" => %{"question" => "interests"}
               })

      assert errors_on(changeset) == %{interaction: ["unsupported interaction type"]}
    end

    test "interaction exchange", %{profiles: [p1, p2], match: match} do
      match_id = match.id

      Matches.subscribe_for_user(p1.user_id)
      Matches.subscribe_for_user(p2.user_id)

      # text interaction from p1 to p2
      assert {:ok, %Interaction{} = interaction} =
               Matches.save_interaction(match.id, p1.user_id, %{
                 "size" => [375, 667],
                 "sticker" => %{"value" => "helloy"}
               })

      from_user_id = p1.user_id
      to_user_id = p2.user_id

      assert %{
               data: %{"size" => [375, 667], "sticker" => %{"value" => "helloy"}},
               from_user_id: ^from_user_id,
               to_user_id: ^to_user_id
             } = interaction

      assert [i1] = Interaction |> where(match_id: ^match_id) |> T.Repo.all()
      assert i1.from_user_id == p1.user_id
      assert i1.to_user_id == p2.user_id
      assert i1.match_id == match.id
      assert i1.data == %{"size" => [375, 667], "sticker" => %{"value" => "helloy"}}

      assert_received {Matches, :interaction, ^i1}
      assert_received {Matches, :interaction, ^i1}

      assert MatchEvent |> T.Repo.all() == []

      # drawing interaction from p2 to p1
      assert {:ok, %Interaction{} = interaction} =
               Matches.save_interaction(match.id, p2.user_id, %{
                 "size" => [428, 926],
                 "sticker" => %{"lines" => "W3sicG9pbnRzIfV0=", "question" => "drawing"}
               })

      assert %{
               data: %{
                 "size" => [428, 926],
                 "sticker" => %{"lines" => "W3sicG9pbnRzIfV0=", "question" => "drawing"}
               },
               from_user_id: ^to_user_id
             } = interaction

      assert [^i1, i2] = Interaction |> where(match_id: ^match_id) |> T.Repo.all()
      assert i2.from_user_id == p2.user_id
      assert i2.to_user_id == p1.user_id
      assert i2.match_id == match.id

      assert i2.data == %{
               "size" => [428, 926],
               "sticker" => %{"lines" => "W3sicG9pbnRzIfV0=", "question" => "drawing"}
             }

      assert_received {Matches, :expiration_reset, _m}
      assert_received {Matches, :expiration_reset, _m}
      assert_received {Matches, :interaction, ^i2}
      assert_received {Matches, :interaction, ^i2}

      assert [%{event: "interaction_exchange"}] = MatchEvent |> T.Repo.all()

      # spotify interaction from p2 to p1
      assert {:ok, %Interaction{}} =
               Matches.save_interaction(match.id, p2.user_id, %{
                 "size" => [428, 926],
                 "sticker" => %{"question" => "spotify"}
               })

      # no match_expiration reset
      refute_received {Matches, :expiration_reset, _m}

      # no additional MatchEvent was added
      assert [%{event: "interaction_exchange"}] = MatchEvent |> T.Repo.all()
    end
  end

  describe "save_interaction/3 side-effects" do
    setup [:with_profiles]

    setup %{profiles: [p1, p2]} do
      Matches.subscribe_for_user(p1.user_id)
      Matches.subscribe_for_user(p2.user_id)
    end

    setup [:with_match, :with_text_interaction, :with_contact_interaction]

    test "push notification is scheduled for mate", %{
      profiles: [%{user_id: from_user_id}, %{user_id: to_user_id}],
      match: %{id: match_id}
    } do
      assert [
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "from_user_id" => ^from_user_id,
                   "to_user_id" => ^to_user_id,
                   "type" => "contact"
                 }
               },
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "from_user_id" => ^from_user_id,
                   "to_user_id" => ^to_user_id,
                   "type" => "message"
                 }
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)
    end

    test "interaction is broadcast via pubsub to us & mate", %{
      profiles: [_p1, %{user_id: to_user_id}]
    } do
      assert_receive {Matches, :interaction, %Interaction{} = interaction_0}
      assert_receive {Matches, :interaction, %Interaction{} = interaction_1}
      assert interaction_0 == interaction_1
      assert interaction_0.data == %{"size" => [375, 667], "sticker" => %{"value" => "helloy"}}
      assert interaction_0.to_user_id == to_user_id

      assert_receive {Matches, :interaction, %Interaction{} = interaction_2}
      assert_receive {Matches, :interaction, %Interaction{} = interaction_3}
      assert interaction_2 == interaction_3

      assert interaction_2.data == %{
               "size" => [375, 667],
               "sticker" => %{"question" => "telegram"}
             }

      assert interaction_2.to_user_id == to_user_id
    end
  end

  describe "mark_interaction_seen/2" do
    setup [:with_profiles, :with_match, :with_text_interaction]

    test "marked seen", %{
      profiles: [%{user_id: _from_user_id}, %{user_id: to_user_id}],
      interaction: %{id: interaction_id, seen: seen}
    } do
      assert seen == false
      assert Matches.mark_interaction_seen(to_user_id, interaction_id) == :ok

      [i] = Interaction |> where(id: ^interaction_id) |> T.Repo.all()
      assert i.seen == true
    end

    test "from sender", %{
      profiles: [%{user_id: from_user_id}, %{user_id: _to_user_id}],
      interaction: %{id: interaction_id, seen: seen}
    } do
      assert seen == false
      assert Matches.mark_interaction_seen(from_user_id, interaction_id) == :error

      [i] = Interaction |> where(id: ^interaction_id) |> T.Repo.all()
      assert i.seen == false
    end
  end

  defp with_profiles(_context) do
    {:ok, profiles: insert_list(2, :profile, hidden?: false)}
  end

  defp with_match(%{profiles: [p1, p2]}) do
    {:ok, match: insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)}
  end

  defp with_text_interaction(%{profiles: [p1, _p2], match: match}) do
    interaction = %{"size" => [375, 667], "sticker" => %{"value" => "helloy"}}

    assert {:ok, %Interaction{} = interaction} =
             Matches.save_interaction(
               match.id,
               p1.user_id,
               interaction
             )

    {:ok, interaction: interaction}
  end

  defp with_contact_interaction(%{profiles: [p1, _p2], match: match}) do
    interaction = %{"size" => [375, 667], "sticker" => %{"question" => "telegram"}}

    assert {:ok, %Interaction{} = interaction} =
             Matches.save_interaction(
               match.id,
               p1.user_id,
               interaction
             )

    {:ok, interaction: interaction}
  end
end
