defmodule T.Bot do
  @moduledoc "TG bot for admins"
  @adapter Application.compile_env!(:t, [__MODULE__, :adapter])

  defp config(key), do: config()[key]

  defp config do
    Application.fetch_env!(:t, __MODULE__)
  end

  def token, do: config(:token)
  def room_id, do: config(:room_id)

  def set_webhook(url) do
    @adapter.set_webhook(url)
  end

  def post_message(text, opts \\ []) do
    @adapter.send_message(room_id(), text, opts)
  end

  def async_post_message(text, opts \\ []) do
    # TODO supervise
    Task.start(fn -> post_message(text, opts) end)
  end

  def async_post_silent_message(text) do
    async_post_message(text, disable_notification: true)
  end

  def handle(_params), do: :ok
end
