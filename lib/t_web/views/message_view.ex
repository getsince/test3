defmodule TWeb.MessageView do
  use TWeb, :view
  alias T.{Media, Matches, Support}

  def render("show.json", %{message: %Matches.Message{} = message}) do
    %Matches.Message{
      id: id,
      author_id: author_id,
      inserted_at: inserted_at,
      kind: kind,
      data: data
    } = message

    timestamp = DateTime.from_naive!(inserted_at, "Etc/UTC")

    %{
      id: id,
      author_id: author_id,
      timestamp: timestamp,
      kind: kind,
      data: maybe_render_url(kind, data)
    }
  end

  def render("show.json", %{message: %Support.Message{} = message}) do
    %Support.Message{
      id: id,
      author_id: author_id,
      inserted_at: inserted_at,
      kind: kind,
      data: data
    } = message

    timestamp = DateTime.from_naive!(inserted_at, "Etc/UTC")

    %{
      id: id,
      author_id: author_id,
      timestamp: timestamp,
      kind: kind,
      data: maybe_render_url(kind, data)
    }
  end

  defp maybe_render_url("photo", %{"s3_key" => s3_key} = data) do
    Map.put(data, "url", Media.imgproxy_url(s3_key))
  end

  defp maybe_render_url("audio", %{"s3_key" => s3_key} = data) do
    Map.put(data, "url", Media.s3_url(s3_key))
  end

  defp maybe_render_url(_kind, data), do: data
end
