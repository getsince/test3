defmodule T.GamesTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.Games
  alias T.Games.Compliment
  alias T.Feeds.{FeedFilter}
  alias T.Chats.{Chat, Message}

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
  end

  describe "list_compliments/1" do
    setup do
      me = onboarded_user(location: moscow_location())
      {:ok, me: me}
    end

    test "no compliments", %{me: me} do
      assert [] == Games.list_compliments(me.id)
    end

    test "compliments have rendered text", %{me: me} do
      mate = onboarded_user(location: moscow_location())

      {random_prompt, _e} = Games.prompts() |> Enum.random()

      c =
        insert(:compliment,
          from_user_id: mate.id,
          to_user_id: me.id,
          prompt: random_prompt
        )

      [%Compliment{} = compliment] = Games.list_compliments(me.id)

      assert compliment.id == c.id
      assert compliment.inserted_at == c.inserted_at
      assert compliment.from_user_id == mate.id
      assert compliment.to_user_id == me.id
      assert compliment.prompt == random_prompt
      assert compliment.revealed == false
      assert compliment.seen == false
      assert compliment.text == Games.render(random_prompt)
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
      prompt_text = Games.render(random_prompt)
      prompt_push_text = Games.render(random_prompt <> "_push")

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

      assert [
               %Message{
                 from_user_id: ^me_id,
                 to_user_id: ^mate_id,
                 data: %{
                   "question" => "compliment",
                   "text" => ^prompt_text,
                   "emoji" => ^emoji,
                   "push_text" => ^prompt_push_text
                 }
               },
               %Message{
                 from_user_id: ^mate_id,
                 to_user_id: ^me_id,
                 data: %{
                   "question" => "compliment",
                   "text" => ^prompt_text,
                   "emoji" => ^emoji,
                   "push_text" => ^prompt_push_text
                 }
               }
             ] = chat.messages
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
      [c] = Compliment |> where(id: ^compliment_id) |> T.Repo.all()
      assert c.seen == true
    end

    test "from sender", %{me: me, compliment: compliment} do
      assert Games.mark_compliment_seen(me.id, compliment.id) == :error

      compliment_id = compliment.id
      [c] = Compliment |> where(id: ^compliment_id) |> T.Repo.all()
      assert c.seen == false
    end
  end
end
