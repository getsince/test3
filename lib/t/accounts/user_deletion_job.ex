defmodule T.Accounts.UserDeletionJob do
  @moduledoc false
  use Oban.Worker
  alias T.{Repo, Accounts}
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    # TODO check if user in someone's feed? They shouldn't be if the profile has been hiiden and 48 hours has passed
    Accounts.User
    |> where(id: ^user_id)
    |> Repo.delete_all()

    {:ok, nil}
  end
end
