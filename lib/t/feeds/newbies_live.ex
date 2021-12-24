defmodule T.Feeds.NewbiesLive do
  @moduledoc """
  Contains Oban jobs to start and finish "Since Live" mode for the new users (aka newbies).
  """

  alias T.Feeds

  defmodule StartJob do
    @moduledoc false
    use Oban.Worker, priority: 1, max_attempts: 1

    @impl true
    def perform(_job) do
      Feeds.newbies_start_live()
    end
  end

  defmodule EndJob do
    @moduledoc false
    use Oban.Worker, priority: 1, max_attempts: 1

    @impl true
    def perform(_job) do
      Feeds.newbies_end_live()
    end
  end
end
