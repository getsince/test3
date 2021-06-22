defmodule T.Feeds.SeenTest do
  use T.DataCase, async: true
  alias T.{Feeds, Matches}

  describe "feed" do
    # TODO seen profile is not returned in feed
    @tag skip: true
    test "seen profile is returned in feed as seen" do
      my_profile = insert(:profile)
      assert %{loaded: [], next_ids: []} == Feeds.batched_demo_feed(my_profile)

      insert_list(10, :profile, gender: "F")

      # I get the feed, nobody is "seen"
      assert %{loaded: not_seen, next_ids: []} = Feeds.batched_demo_feed(my_profile)
      assert length(not_seen) == 10
      Enum.each(not_seen, fn p -> assert p.seen? == false end)

      # then I "see" some profiles (test broadcast)
      to_be_seen = Enum.take(not_seen, 3)

      Enum.each(to_be_seen, fn p ->
        # TODO verify broadcast
        assert {:ok, %Feeds.SeenProfile{}} =
                 Feeds.mark_profile_seen(p.user_id, by: my_profile.user_id)
      end)

      # then I get feed again, and those profiles I've seen are marked as "seen"
      assert %{loaded: loaded, next_ids: []} = Feeds.batched_demo_feed(my_profile)

      {seen, not_seen} = Enum.split(loaded, 3)
      Enum.each(seen, fn p -> assert p.seen? == true end)
      Enum.each(not_seen, fn p -> assert p.seen? == false end)

      # TODO
      # also the profiles I've seen are put in the end of the list?
    end

    test "double mark_profile_seen doesn't raise but returns invalid changeset" do
      me = insert(:user)
      not_me = insert(:user)

      assert {:ok, %Feeds.SeenProfile{}} = Feeds.mark_profile_seen(not_me.id, by: me.id)

      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Feeds.mark_profile_seen(not_me.id, by: me.id)

      assert errors_on(changeset) == %{seen: ["has already been taken"]}
    end
  end

  describe "likers" do
    test "seen likes are marked seen in all_profile_likes_with_liker_profile" do
      my_profile = insert(:profile)
      assert [] == Feeds.all_profile_likes_with_liker_profile(my_profile.user_id)

      insert_list(10, :profile, gender: "F")
      |> Enum.with_index(1)
      |> Enum.each(fn {p, expected_likes_count} ->
        assert {:ok,
                %{
                  bump_likes: ^expected_likes_count,
                  like: %Feeds.ProfileLike{},
                  match: nil,
                  mutual: nil,
                  push: nil
                }} = Feeds.like_profile(p.user_id, my_profile.user_id)
      end)

      # I get the likes feed, no like is "seen"
      not_seen = Feeds.all_profile_likes_with_liker_profile(my_profile.user_id)
      assert length(not_seen) == 10
      Enum.each(not_seen, fn like -> assert like.seen? == false end)

      # then I "see" some profiles (test broadcast)
      to_be_seen = Enum.take(not_seen, 3)

      Enum.each(to_be_seen, fn %Feeds.ProfileLike{by_user_id: user_id} ->
        # TODO verify broadcast
        assert true = Feeds.mark_liker_seen(user_id, by: my_profile.user_id)
      end)

      # then I get likes feed again, and those likes I've seen are marked as "seen" duh
      likes = Feeds.all_profile_likes_with_liker_profile(my_profile.user_id)

      {seen, not_seen} = Enum.split(likes, 3)
      Enum.each(seen, fn l -> assert l.seen? == true end)
      Enum.each(not_seen, fn l -> assert l.seen? == false end)

      # TODO
      # also the profiles I've seen are put in the end of the list?
    end

    test "double mark_liker_seen doesn't raise" do
      me = insert(:profile)
      not_me = insert(:profile)
      Feeds.like_profile(not_me.user_id, me.user_id)

      assert true == Feeds.mark_liker_seen(not_me.user_id, by: me.user_id)
      assert true == Feeds.mark_liker_seen(not_me.user_id, by: me.user_id)
    end
  end

  describe "timeslots" do
    @slots [
      "2021-03-23 14:45:00Z",
      "2021-03-23 15:00:00Z",
      "2021-03-23 15:15:00Z"
    ]

    @reference ~U[2021-03-23 14:00:00Z]

    test "seeing slot makes it seen" do
      [picker, offerer] = insert_list(2, :profile)
      match = insert(:match, user_id_1: picker.user_id, user_id_2: offerer.user_id)

      # offered slot is seen by offerer, not seen by picker
      assert {:ok, %{timeslot: %Matches.Timeslot{seen?: nil = _doenst_matter}}} =
               Matches.save_slots_offer(@slots,
                 match: match.id,
                 from: offerer.user_id,
                 reference: @reference
               )

      assert [%Matches.Match{timeslot: %Matches.Timeslot{seen?: false}}] =
               Matches.get_current_matches(picker.user_id)

      assert [%Matches.Match{timeslot: %Matches.Timeslot{seen?: true}}] =
               Matches.get_current_matches(offerer.user_id)

      # offerer can't mark slot seen right now
      assert false ==
               Matches.mark_timeslot_seen_or_delete_expired(match.id,
                 by: offerer.user_id,
                 reference: @reference
               )

      assert [%Matches.Match{timeslot: %Matches.Timeslot{seen?: false}}] =
               Matches.get_current_matches(picker.user_id)

      assert [%Matches.Match{timeslot: %Matches.Timeslot{seen?: true}}] =
               Matches.get_current_matches(offerer.user_id)

      # picker can mark_seen slot, after that it's seen by picker and offerer
      assert :seen ==
               Matches.mark_timeslot_seen_or_delete_expired(match.id,
                 by: picker.user_id,
                 reference: @reference
               )

      assert [%Matches.Match{timeslot: %Matches.Timeslot{seen?: true}}] =
               Matches.get_current_matches(picker.user_id)

      assert [%Matches.Match{timeslot: %Matches.Timeslot{seen?: true}}] =
               Matches.get_current_matches(offerer.user_id)

      # picker can select slot, after that it's seen by picker, but not seen by offerer

      assert {:ok, %Matches.Timeslot{seen?: false = _doesnt_matter}} =
               Matches.accept_slot("2021-03-23 15:00:00Z",
                 match: match.id,
                 picker: picker.user_id,
                 reference: @reference
               )

      assert [%Matches.Match{timeslot: %Matches.Timeslot{seen?: true}}] =
               Matches.get_current_matches(picker.user_id)

      assert [%Matches.Match{timeslot: %Matches.Timeslot{seen?: false}}] =
               Matches.get_current_matches(offerer.user_id)

      # picker can't mark slot seen right now
      assert false ==
               Matches.mark_timeslot_seen_or_delete_expired(match.id,
                 by: picker.user_id,
                 reference: @reference
               )

      assert [%Matches.Match{timeslot: %Matches.Timeslot{seen?: true}}] =
               Matches.get_current_matches(picker.user_id)

      assert [%Matches.Match{timeslot: %Matches.Timeslot{seen?: false}}] =
               Matches.get_current_matches(offerer.user_id)

      # offerer can mark_seen selected slot, after that it's seen by offerer and picker
      assert :seen ==
               Matches.mark_timeslot_seen_or_delete_expired(match.id,
                 by: offerer.user_id,
                 reference: @reference
               )

      assert [%Matches.Match{timeslot: %Matches.Timeslot{seen?: true}}] =
               Matches.get_current_matches(picker.user_id)

      assert [%Matches.Match{timeslot: %Matches.Timeslot{seen?: true}}] =
               Matches.get_current_matches(offerer.user_id)
    end

    # TODO broadcast deletion
    test "seeing expired timeslot.slots deletes it" do
      [picker, offerer] = insert_list(2, :profile)
      match = insert(:match, user_id_1: picker.user_id, user_id_2: offerer.user_id)

      assert {:ok, %{timeslot: %Matches.Timeslot{seen?: nil = _doenst_matter}}} =
               Matches.save_slots_offer(@slots,
                 match: match.id,
                 from: offerer.user_id,
                 reference: @reference
               )

      # offerer can't delete it
      assert false ==
               Matches.mark_timeslot_seen_or_delete_expired(match.id,
                 by: offerer.user_id,
                 reference: ~U[2021-03-23 15:30:00Z]
               )

      assert [%Matches.Match{timeslot: %Matches.Timeslot{}}] =
               Matches.get_current_matches(picker.user_id)

      assert [%Matches.Match{timeslot: %Matches.Timeslot{}}] =
               Matches.get_current_matches(offerer.user_id)

      # only picker can
      assert :deleted =
               Matches.mark_timeslot_seen_or_delete_expired(match.id,
                 by: picker.user_id,
                 reference: ~U[2021-03-23 15:30:00Z]
               )

      assert [%Matches.Match{timeslot: nil}] = Matches.get_current_matches(picker.user_id)
      assert [%Matches.Match{timeslot: nil}] = Matches.get_current_matches(offerer.user_id)
    end

    test "seeing expired timeslot.selected_slot deletes it" do
      [picker, offerer] = insert_list(2, :profile)
      match = insert(:match, user_id_1: picker.user_id, user_id_2: offerer.user_id)

      assert {:ok, %{timeslot: %Matches.Timeslot{seen?: nil = _doenst_matter}}} =
               Matches.save_slots_offer(@slots,
                 match: match.id,
                 from: offerer.user_id,
                 reference: @reference
               )

      assert {:ok, %Matches.Timeslot{seen?: false = _doesnt_matter}} =
               Matches.accept_slot("2021-03-23 15:00:00Z",
                 match: match.id,
                 picker: picker.user_id,
                 reference: @reference
               )

      # offerer can't delete it
      assert false ==
               Matches.mark_timeslot_seen_or_delete_expired(match.id,
                 by: offerer.user_id,
                 reference: ~U[2021-03-23 15:15:00Z]
               )

      assert [%Matches.Match{timeslot: %Matches.Timeslot{}}] =
               Matches.get_current_matches(picker.user_id)

      assert [%Matches.Match{timeslot: %Matches.Timeslot{}}] =
               Matches.get_current_matches(offerer.user_id)

      # only picker can
      assert :deleted =
               Matches.mark_timeslot_seen_or_delete_expired(match.id,
                 by: picker.user_id,
                 reference: ~U[2021-03-23 15:15:00Z]
               )

      assert [%Matches.Match{timeslot: nil}] = Matches.get_current_matches(picker.user_id)
      assert [%Matches.Match{timeslot: nil}] = Matches.get_current_matches(offerer.user_id)
    end

    test "mark_timeslot_seen_or_delete_expired when match/timeslot doesn't exist" do
      [picker, offerer] = insert_list(2, :profile)

      assert_raise Ecto.NoResultsError, fn ->
        Matches.mark_timeslot_seen_or_delete_expired(Ecto.UUID.generate(),
          by: picker.user_id
        )
      end

      match = insert(:match, user_id_1: picker.user_id, user_id_2: offerer.user_id)

      assert_raise Ecto.NoResultsError, fn ->
        Matches.mark_timeslot_seen_or_delete_expired(match.id, by: picker.user_id)
      end
    end
  end

  describe "matches" do
    test "it works" do
      my_profile = insert(:profile)

      assert [] == Matches.get_current_matches(my_profile.user_id)

      insert_list(10, :profile)
      |> Enum.each(fn p ->
        insert(:match, user_id_1: my_profile.user_id, user_id_2: p.user_id)
      end)

      # I get matches, no match is "seen"
      not_seen = Matches.get_current_matches(my_profile.user_id)
      assert length(not_seen) == 10
      Enum.each(not_seen, fn m -> assert m.seen? == false end)

      # then I "see" some matches (test broadcast)
      to_be_seen = Enum.take(not_seen, 3)

      Enum.each(to_be_seen, fn m ->
        # TODO verify broadcast
        assert {:ok, %Matches.SeenMatch{}} = Matches.mark_match_seen(m.id, by: my_profile.user_id)
      end)

      # then I get matches again, and those matches I've seen are marked as "seen"
      matches = Matches.get_current_matches(my_profile.user_id)
      assert length(matches) == 10

      {seen, not_seen} = Enum.split(matches, 3)
      Enum.each(seen, fn m -> assert m.seen? == true end)
      Enum.each(not_seen, fn m -> assert m.seen? == false end)

      # TODO
      # also the matches I've seen are put in the end of the list?
    end

    test "double mark_match_seen doesn't raise but returns invalid changeset" do
      me = insert(:user)
      not_me = insert(:user)
      match = insert(:match, user_id_1: me.id, user_id_2: not_me.id)

      assert {:ok, %Matches.SeenMatch{}} = Matches.mark_match_seen(match.id, by: me.id)

      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Matches.mark_match_seen(match.id, by: me.id)

      assert errors_on(changeset) == %{seen: ["has already been taken"]}
    end
  end
end
