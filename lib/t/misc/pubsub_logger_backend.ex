defmodule T.PubSubLoggerBackend do
  @moduledoc false
  @behaviour :gen_event

  @impl true
  def init(_opts) do
    {:ok, nil}
  end

  @impl true
  def handle_call({:configure, _options}, state) do
    {:ok, :ok, state}
  end

  @impl true
  def handle_event({level, _gl, {Logger, msg, ts, _md}}, state) do
    Phoenix.PubSub.broadcast(T.PubSub, "logs", {level, ts, msg})
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  @impl true
  def handle_info(_, state) do
    {:ok, state}
  end

  @impl true
  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end
end
