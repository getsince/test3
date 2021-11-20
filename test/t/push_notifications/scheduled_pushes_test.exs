defmodule T.PushNotifications.ScheduledPushesTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.Accounts

  describe "scheduled pushes" do
    test "push to user with no story is scheduled" do
      day_ago = DateTime.utc_now() |> DateTime.add(-24 * 60 * 60 - 30)

      user = onboarded_user(story: nil, last_active: day_ago)

      Accounts.push_users_to_complete_onboarding()

      user_id = user.id

      assert [
               %Oban.Job{
                 args: %{
                   "user_id" => ^user_id,
                   "type" => "complete_onboarding"
                 }
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)
    end
  end

  test "push to user with story is not scheduled" do
    day_ago = DateTime.utc_now() |> DateTime.add(-24 * 60 * 60 - 30)

    _user = onboarded_user(last_active: day_ago)

    Accounts.push_users_to_complete_onboarding()

    assert [] = all_enqueued(worker: T.PushNotifications.DispatchJob)
  end
end
