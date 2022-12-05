defmodule T.Games.ComplimentLimitResetJob do
  @moduledoc "Resets compliment limit when the time comes"
  use Oban.Worker
  alias T.Games

  @impl true
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    if compliment_limit = Games.fetch_compliment_limit(user_id) do
      Games.local_reset_compliment_limit(compliment_limit)
    else
      :discard
    end
  end
end
