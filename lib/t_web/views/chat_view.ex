defmodule TWeb.ChatView do
  use TWeb, :view
  alias TWeb.{FeedView, ViewHelpers}
  alias T.Chats.Message

  def render("chat.json", %{id: id} = assigns) do
    %{"id" => id, "profile" => render(FeedView, "feed_profile_with_distance.json", assigns)}
    |> maybe_put("inserted_at", ensure_utc(assigns[:inserted_at]))
    |> render_messages(assigns[:messages], assigns[:screen_width])
  end

  def render("message.json", %{message: message, screen_width: screen_width}) do
    %Message{
      id: id,
      from_user_id: from_user_id,
      data: sticker,
      seen: seen
    } = message

    %{
      "id" => id,
      "message" => ViewHelpers.process_sticker(sticker, screen_width),
      "inserted_at" => datetime(id),
      "from_user_id" => from_user_id,
      "seen" => seen
    }
  end

  defp render_messages(map, messages, screen_width) when is_list(messages) do
    Map.put(
      map,
      "messages",
      messages
      |> Enum.map(fn message ->
        render("message.json", %{message: message, screen_width: screen_width})
      end)
    )
  end

  defp render_messages(map, _messages, _screen_width), do: map

  defp datetime(<<_::288>> = uuid) do
    datetime(Ecto.Bigflake.UUID.dump!(uuid))
  end

  defp datetime(<<unix::64, _rest::64>>) do
    unix |> DateTime.from_unix!(:millisecond) |> DateTime.truncate(:second)
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, _k, false), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp ensure_utc(%DateTime{} = datetime), do: datetime
  defp ensure_utc(%NaiveDateTime{} = naive), do: DateTime.from_naive!(naive, "Etc/UTC")
  defp ensure_utc(nil), do: nil
end
