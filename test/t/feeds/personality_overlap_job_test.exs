defmodule T.Feeds.PersonalityOverlapJobTest do
  use T.DataCase, async: true
  alias T.Feeds.{PersonalityOverlapJob, PersonalityOverlap}

  describe "perform" do
    test "when user doesn't exist" do
      assert {:ok, :no_user} ==
               PersonalityOverlapJob.perform(%Oban.Job{args: %{"user_id" => Ecto.UUID.generate()}})
    end

    test "when there are no other users" do
      me = insert(:profile)

      assert {:ok, %{updated: 0}} ==
               PersonalityOverlapJob.perform(%Oban.Job{args: %{"user_id" => me.user_id}})
    end

    test "when there are other users # < batch_size -> no reschedule" do
      {p1_expected_score, %{user_id: p1_id}} =
        {_expected_score = 4,
         insert(:profile,
           gender: "F",
           tastes: %{
             "music" => ["a", "b", "f"],
             "movies" => ["q", "c", "e"],
             "smoking" => "nope",
             "pets" => ["q"]
           }
         )}

      %{user_id: me_id} =
        me =
        insert(:profile,
          gender: "M",
          tastes: %{
            "music" => ["a", "b", "c"],
            "movies" => ["a", "b", "c"],
            "alcohol" => "nope",
            "smoking" => "nope"
          }
        )

      {p2_expected_score, %{user_id: p2_id}} =
        {_expected_score = 0,
         insert(:profile,
           gender: "F",
           tastes: %{"cuisines" => ["a", "b"]}
         )}

      insert(:profile,
        gender: "M",
        tastes: %{
          "music" => ["a", "b", "c"],
          "movies" => ["a", "b", "c"],
          "alcohol" => "nope",
          "smoking" => "nope"
        }
      )

      assert {:ok, %{updated: 2}} ==
               PersonalityOverlapJob.perform(%Oban.Job{args: %{"user_id" => me.user_id}})

      assert [
               %PersonalityOverlap{
                 score: ^p1_expected_score,
                 user_id_1: ^p1_id,
                 user_id_2: ^me_id
               },
               %PersonalityOverlap{
                 score: ^p2_expected_score,
                 user_id_1: ^me_id,
                 user_id_2: ^p2_id
               }
             ] = Repo.all(PersonalityOverlap)
    end

    test "when there are other users # > batch_size -> reschedules" do
      {p1_expected_score, %{user_id: p1_id}} =
        {_expected_score = 4,
         insert(:profile,
           gender: "F",
           tastes: %{
             "music" => ["a", "b", "f"],
             "movies" => ["q", "c", "e"],
             "smoking" => "nope",
             "pets" => ["q"]
           }
         )}

      %{user_id: me_id} =
        me =
        insert(:profile,
          gender: "M",
          tastes: %{
            "music" => ["a", "b", "c"],
            "movies" => ["a", "b", "c"],
            "alcohol" => "nope",
            "smoking" => "nope"
          }
        )

      {p2_expected_score, %{user_id: p2_id}} =
        {_expected_score = 0,
         insert(:profile,
           gender: "F",
           tastes: %{"cuisines" => ["a", "b"]}
         )}

      insert(:profile,
        gender: "M",
        tastes: %{
          "music" => ["a", "b", "c"],
          "movies" => ["a", "b", "c"],
          "alcohol" => "nope",
          "smoking" => "nope"
        }
      )

      assert {:ok, %Oban.Job{args: %{after_id: ^p1_id, user_id: ^me_id} = args} = job2} =
               PersonalityOverlapJob.perform(%Oban.Job{
                 args: %{"user_id" => me.user_id, "batch_size" => 1}
               })

      assert [
               %PersonalityOverlap{
                 score: ^p1_expected_score,
                 user_id_1: ^p1_id,
                 user_id_2: ^me_id
               }
             ] = Repo.all(PersonalityOverlap)

      job2 = %{job2 | args: Map.new(args, fn {k, v} -> {to_string(k), v} end)}
      assert {:ok, %{updated: 1}} == PersonalityOverlapJob.perform(job2)

      assert [
               %PersonalityOverlap{
                 score: ^p1_expected_score,
                 user_id_1: ^p1_id,
                 user_id_2: ^me_id
               },
               %PersonalityOverlap{
                 score: ^p2_expected_score,
                 user_id_1: ^me_id,
                 user_id_2: ^p2_id
               }
             ] = Repo.all(PersonalityOverlap)
    end
  end
end
