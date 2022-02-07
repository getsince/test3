defmodule T.Events do
  @moduledoc """
  Use functions defined here to store events to local SQLite replicated to S3.
  """

  alias T.Events.Buffer

  @doc """
  Example:

      # https://github.com/getsince/test3/issues/397#issuecomment-962966391
      event = "viewed"
      actor = "0000017b-b0cf-d3e8-0242-ac1100020000"
      data = %{profile: "0000017b-b0cf-d3e8-0242-ac1100020000", started_at: ~U[2022-02-07 13:46:43.224624Z], ended_at: ~U[2022-02-07 13:46:52.172979Z]}
      save_event(event, actor, data)

  """
  @spec save_event(String.t(), Ecto.Bigflake.UUID.t(), map) :: :ok
  def save_event(name, actor, data) do
    GenServer.cast(Buffer, {:add, build_event(name, actor, data)})
  end

  @spec save_event(String.t(), Ecto.Bigflake.UUID.t()) :: :ok
  def save_event(name, actor) do
    GenServer.cast(Buffer, {:add, build_event(name, actor)})
  end

  @spec save_event(module | pid, String.t(), Ecto.Bigflake.UUID.t(), map) :: :ok
  def save_event(buffer, name, actor, data) do
    GenServer.cast(buffer, {:add, build_event(name, actor, data)})
  end

  defp build_event(name, actor, data) do
    %{name: name, actor: actor, data: data}
  end

  defp build_event(name, actor) do
    %{name: name, actor: actor}
  end
end
