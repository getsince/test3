defmodule TWeb.MatchView do
  use TWeb, :view
  alias T.Matches.Message
  alias T.Media

  def render("message.json", %{message: %Message{} = message}) do
    message
    |> Map.take([:id, :author_id, :inserted_at, :kind, :data])
    |> maybe_render_s3_url()
  end

  defp maybe_render_s3_url(%{data: %{"s3_key" => s3_key} = data} = message) do
    %{message | data: Map.put(data, "url", Media.url(s3_key))}
  end

  defp maybe_render_s3_url(message), do: message
end
