defmodule T.Feeds.Live do
  @moduledoc """
  Contains Oban jobs to start and finish "Since Live" mode for all users.
  """

  alias T.Feeds

  defmodule StartJob do
    @moduledoc false
    use Oban.Worker, priority: 1, max_attempts: 1

    @impl true
    def perform(_job) do
      Feeds.live_mode_start()
    end
  end

  defmodule EndJob do
    @moduledoc false
    use Oban.Worker, priority: 1, max_attempts: 1

    @impl true
    def perform(_job) do
      Feeds.live_mode_end()
    end
  end
end
