defmodule Since.GamesTest do
  use Since.DataCase, async: true
  use Oban.Testing, repo: Since.Repo

  alias Since.Games
  alias Since.Games.Compliment
  alias Since.Feeds.{FeedFilter}
  alias Since.Chats.{Chat, Message}

  describe "fetch_game/4" do
    setup do
      me = onboarded_user(location: moscow_location())
      {:ok, me: me}
    end

    test "with no data in db", %{me: me} do
      assert nil ==
               Games.fetch_game(
                 me.id,
                 me.profile.location,
                 _gender = "M",
                 _feed_filter = %FeedFilter{
                   genders: ["F"],
                   min_age: nil,
                   max_age: nil,
                   distance: nil
                 }
               )
    end

    test "with compliment_limit reached", %{me: me} do
      for _ <- 1..Games.compliment_limit() do
        u = onboarded_user()
        assert {:ok, %Compliment{}} = Games.save_compliment(u.id, me.id, "like")
      end

      p = onboarded_user()
      assert {:error, %DateTime{}} = Games.save_compliment(p.id, me.id, "like")
    end

    test "with no active users", %{me: me} do
      insert_list(3, :profile, gender: "F")

      assert nil ==
               Games.fetch_game(
                 me.id,
                 me.profile.location,
                 _gender = "M",
                 _feed_filter = %FeedFilter{
                   genders: ["F"],
                   min_age: nil,
                   max_age: nil,
                   distance: nil
                 }
               )
    end

    test "with no users of preferred gender", %{me: me} do
      _others = insert_list(3, :profile, gender: "M")

      assert nil ==
               Games.fetch_game(
                 me.id,
                 me.profile.location,
                 _gender = "M",
                 _feed_filter = %FeedFilter{
                   genders: ["F"],
                   min_age: nil,
                   max_age: nil,
                   distance: nil
                 }
               )
    end

    test "with users of preferred gender but not interested", %{me: me} do
      others = insert_list(3, :profile, gender: "F")

      for profile <- others do
        insert(:gender_preference, user_id: profile.user_id, gender: "F")
      end

      assert nil ==
               Games.fetch_game(
                 me.id,
                 me.profile.location,
                 _gender = "M",
                 _feed_filter = %FeedFilter{
                   genders: ["F"],
                   min_age: nil,
                   max_age: nil,
                   distance: nil
                 }
               )
    end

    test "with users less than game_set_count", %{me: me} do
      others = insert_list(10, :profile, gender: "F")

      for profile <- others do
        insert(:gender_preference, user_id: profile.user_id, gender: "M")
      end

      %{"profiles" => profiles, "prompt" => prompt} =
        Games.fetch_game(
          me.id,
          me.profile.location,
          _gender = "M",
          _feed_filter = %FeedFilter{
            genders: ["F"],
            min_age: nil,
            max_age: nil,
            distance: nil
          }
        )

      {_emoji, _tag, _text} = prompt

      assert length(profiles) == 10
    end

    test "with users more than game_set_count", %{me: me} do
      others = insert_list(10 + Games.game_set_count(), :profile, gender: "F")

      for profile <- others do
        insert(:gender_preference, user_id: profile.user_id, gender: "M")
      end

      %{"profiles" => profiles, "prompt" => prompt} =
        Games.fetch_game(
          me.id,
          me.profile.location,
          _gender = "M",
          _feed_filter = %FeedFilter{
            genders: ["F"],
            min_age: nil,
            max_age: nil,
            distance: nil
          }
        )

      {_emoji, _tag, _text} = prompt

      assert length(profiles) == Games.game_set_count()
    end

    test "with complimenters", %{me: me} do
      mates = Enum.map(0..10, fn _i -> onboarded_user(location: moscow_location()) end)

      for mate <- mates do
        {random_prompt, _e} = Games.prompts() |> Enum.random()
        insert(:compliment, from_user_id: mate.id, to_user_id: me.id, prompt: random_prompt)
      end

      others = insert_list(Games.game_set_count(), :profile, gender: "F")
      for profile <- others, do: insert(:gender_preference, user_id: profile.user_id, gender: "M")

      %{"profiles" => profiles, "prompt" => _prompt} =
        Games.fetch_game(
          me.id,
          me.profile.location,
          _gender = "M",
          _feed_filter = %FeedFilter{
            genders: ["F"],
            min_age: nil,
            max_age: nil,
            distance: nil
          }
        )

      assert length(profiles) == Games.game_set_count()

      complimenters =
        profiles |> Enum.filter(fn p -> p.user_id in Enum.map(mates, fn m -> m.id end) end)

      assert length(complimenters) == 2
    end
  end

  describe "list_compliments/1" do
    setup do
      me = onboarded_user(location: moscow_location())
      mate = onboarded_user(location: moscow_location())
      {:ok, me: me, mate: mate}
    end

    test "no compliments", %{me: me} do
      assert [] == Games.list_compliments(me.id, me.profile.location, false)
    end

    test "non premium", %{me: me, mate: mate} do
      {random_prompt, _e} = Games.prompts() |> Enum.random()

      c = insert(:compliment, from_user_id: mate.id, to_user_id: me.id, prompt: random_prompt)

      [%Compliment{} = compliment] = Games.list_compliments(me.id, me.profile.location, false)

      assert compliment.id == c.id
      assert compliment.inserted_at == c.inserted_at
      assert compliment.from_user_id == mate.id
      assert compliment.to_user_id == me.id
      assert compliment.prompt == random_prompt
      assert compliment.revealed == false
      assert compliment.seen == false
      assert compliment.profile == nil
    end

    test "premium user has revealed compliments", %{me: me, mate: mate} do
      assert {:ok, _changes} = Since.Accounts.set_premium(me.id, true)

      {random_prompt, _e} = Games.prompts() |> Enum.random()

      insert(:compliment, from_user_id: mate.id, to_user_id: me.id, prompt: random_prompt)

      [%Compliment{} = compliment] = Games.list_compliments(me.id, me.profile.location, true)

      assert compliment.profile ==
               Since.Feeds.get_mate_feed_profile(mate.id, mate.profile.location)
    end
  end

  describe "save_compliment/3" do
    setup do
      me = onboarded_user(location: moscow_location())
      mate = onboarded_user(location: moscow_location())
      {:ok, me: me, mate: mate}
    end

    test "bad prompt", %{me: me, mate: mate} do
      prompt = "hahahah"

      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Games.save_compliment(mate.id, me.id, prompt)

      assert errors_on(changeset) == %{compliment: ["unrecognized prompt"]}
    end

    test "compliment exchange", %{me: me, mate: mate} do
      {random_prompt, emoji} = Games.prompts() |> Enum.random()

      Games.subscribe_for_user(me.id)
      Games.subscribe_for_user(mate.id)

      # we compliment mate
      {:ok, %Compliment{} = compliment} = Games.save_compliment(mate.id, me.id, random_prompt)

      # mate receives our compliment
      assert_received {Games, :compliment, ^compliment}

      # mate compliments us
      {:ok, %Chat{} = chat} = Games.save_compliment(me.id, mate.id, random_prompt)

      # both of us receive chat with compliments
      assert_received {Games, :chat, ^chat}
      assert_received {Games, :chat, ^chat}

      me_id = me.id
      mate_id = mate.id
      me_name = me.profile.name
      me_gender = me.profile.gender

      assert [
               %Message{
                 id: message_id,
                 from_user_id: ^me_id,
                 to_user_id: ^mate_id,
                 data: %{"question" => "compliment", "prompt" => random_prompt}
               },
               %Message{
                 id: message_id_1,
                 from_user_id: ^mate_id,
                 to_user_id: ^me_id,
                 data: %{"question" => "compliment", "prompt" => random_prompt}
               }
             ] = chat.messages

      assert [
               %Oban.Job{
                 args: %{
                   "compliment_id" => ^message_id_1,
                   "from_user_id" => ^mate_id,
                   "to_user_id" => ^me_id,
                   "type" => "compliment_revealed",
                   "prompt" => ^random_prompt,
                   "emoji" => ^emoji
                 }
               },
               %Oban.Job{
                 args: %{
                   "compliment_id" => ^message_id,
                   "to_user_id" => ^mate_id,
                   "type" => "compliment",
                   "prompt" => ^random_prompt,
                   "emoji" => ^emoji,
                   "premium" => false,
                   "from_user_name" => ^me_name,
                   "from_user_gender" => ^me_gender
                 }
               },
               %Oban.Job{args: %{"type" => "complete_onboarding"}},
               %Oban.Job{args: %{"type" => "complete_onboarding"}}
             ] = all_enqueued(worker: Since.PushNotifications.DispatchJob)
    end
  end

  describe "mark_compliment_seen/2" do
    setup do
      me = onboarded_user(location: moscow_location())
      mate = onboarded_user(location: moscow_location())
      {_e, random_prompt} = Games.prompts() |> Enum.random()

      compliment =
        insert(:compliment, from_user_id: me.id, to_user_id: mate.id, prompt: random_prompt)

      {:ok, me: me, mate: mate, compliment: compliment}
    end

    test "marked seen", %{mate: mate, compliment: compliment} do
      assert Games.mark_compliment_seen(mate.id, compliment.id) == :ok

      compliment_id = compliment.id
      [c] = Compliment |> where(id: ^compliment_id) |> Since.Repo.all()
      assert c.seen == true
    end

    test "from sender", %{me: me, compliment: compliment} do
      assert Games.mark_compliment_seen(me.id, compliment.id) == :error

      compliment_id = compliment.id
      [c] = Compliment |> where(id: ^compliment_id) |> Since.Repo.all()
      assert c.seen == false
    end
  end
end
