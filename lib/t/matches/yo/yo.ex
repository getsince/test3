defmodule T.Matches.Yo do
  use Supervisor
  # so the logic
  # we want to send a YO to user
  # we get all device ids for user
  # device ids empty -> send sms
  # device ids not empty, try to send a notification to each device, if all notifications fail -> semd sms
  # if at least one doesn't fail, spawn an ack waiter process which waits for 5 seconds
  # then if no ack is received -> send SMS

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @task_sup __MODULE__.TaskSupervisor
  def task_sup do
    @task_sup
  end

  @impl true
  def init(_opts) do
    children = [
      {Task.Supervisor, name: @task_sup, max_children: :infinity}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # @doc "send_yo()"
  # def send_yo(device_ids, opts \\ []) do
  # end
end
