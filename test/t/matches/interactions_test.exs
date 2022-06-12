defmodule T.Matches.InteractionsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.Matches
  alias T.Matches.Interaction

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

      match_event = Matches.MatchEvent |> T.Repo.all()

      assert length(match_event) == 0
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

    test "interaction types", %{profiles: [p1, p2], match: match} do
      Matches.subscribe_for_user(p1.user_id)
      Matches.subscribe_for_user(p2.user_id)

      # text interaction
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

      assert [i1] = Matches.history_list_interactions(match.id)
      assert i1.from_user_id == p1.user_id
      assert i1.to_user_id == p2.user_id
      assert i1.match_id == match.id
      assert i1.data == %{"size" => [375, 667], "sticker" => %{"value" => "helloy"}}

      assert_received {Matches, :interaction, ^i1}
      assert_received {Matches, :interaction, ^i1}

      # drawing interaction
      assert {:ok, %Interaction{} = interaction} =
               Matches.save_interaction(match.id, p1.user_id, %{
                 "size" => [428, 926],
                 "sticker" => %{"lines" => "W3sicG9pbnRzIfV0=", "question" => "drawing"}
               })

      assert %{
               data: %{
                 "size" => [428, 926],
                 "sticker" => %{"lines" => "W3sicG9pbnRzIfV0=", "question" => "drawing"}
               },
               from_user_id: ^from_user_id
             } = interaction

      assert [^i1, i2] = Matches.history_list_interactions(match.id)
      assert i2.from_user_id == p1.user_id
      assert i2.to_user_id == p2.user_id
      assert i2.match_id == match.id

      assert i2.data == %{
               "size" => [428, 926],
               "sticker" => %{"lines" => "W3sicG9pbnRzIfV0=", "question" => "drawing"}
             }

      assert_received {Matches, :interaction, ^i2}
      assert_received {Matches, :interaction, ^i2}
    end
  end

  describe "save_contact_offer/3 side-effects" do
    setup [:with_profiles]

    setup %{profiles: [_p1, p2]} do
      Matches.subscribe_for_user(p2.user_id)
    end

    setup [:with_match, :with_interaction]

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
                   "type" => "message"
                 }
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)
    end

    test "offer is broadcast via pubsub to mate", %{profiles: [_p1, %{user_id: to_user_id}]} do
      assert_receive {Matches, :interaction, %Interaction{} = interaction}

      assert interaction.data == %{"size" => [375, 667], "sticker" => %{"value" => "helloy"}}

      assert interaction.to_user_id == to_user_id
    end
  end

  defp with_profiles(_context) do
    {:ok, profiles: insert_list(2, :profile, hidden?: false)}
  end

  defp with_match(%{profiles: [p1, p2]}) do
    {:ok, match: insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)}
  end

  defp with_interaction(%{profiles: [p1, _p2], match: match}) do
    interaction = %{"size" => [375, 667], "sticker" => %{"value" => "helloy"}}

    assert {:ok, %Interaction{} = interaction} =
             Matches.save_interaction(
               match.id,
               p1.user_id,
               interaction
             )

    {:ok, interaction: interaction}
  end
end
