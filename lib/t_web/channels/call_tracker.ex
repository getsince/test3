# TODO move call tracker to T. namespace?
defmodule TWeb.CallTracker do
  @moduledoc """
  Tracks users in calls.

  Used to provide "user is busy" information to the callers.
  """
  use Phoenix.Tracker

  @type uuid :: Ecto.Bigflake.UUID.t()
  @topic "in_call"

  def start_link(opts) do
    opts = Keyword.merge([name: __MODULE__, pubsub_server: T.PubSub], opts)
    Phoenix.Tracker.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_diff(_diff, state) do
    {:ok, state}
  end

  @doc """
  Call `track/1` to indicate that the user has entered a call.
  """
  @spec track(uuid) :: {:ok, ref :: binary} | {:error, reason :: term}
  @spec track(module | pid, uuid) :: {:ok, ref :: binary} | {:error, reason :: term}
  def track(tracker \\ __MODULE__, user_id) do
    Phoenix.Tracker.track(tracker, self(), @topic, user_id, %{})
  end

  @doc """
  Returns `true` if user is in a call, and `false` otherwise
  """
  @spec in_call?(uuid) :: boolean
  @spec in_call?(module | pid, uuid) :: boolean
  def in_call?(tracker \\ __MODULE__, user_id) do
    presences = Phoenix.Tracker.get_by_key(tracker, @topic, user_id)
    not Enum.empty?(presences)
  end
end
