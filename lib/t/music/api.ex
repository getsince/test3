defmodule T.Music.API do
  @behaviour T.Music

  # TODO don't leak tokens to logs
  @impl true
  def get_song(id) when is_binary(id) do
    url = "https://api.music.apple.com/v1/catalog/ru/songs/#{id}"

    %HTTPoison.Response{body: body, status_code: 200} =
      HTTPoison.get!(url, [{"Authorization", "Bearer #{T.Music.token()}"}])

    Jason.decode!(body)
  end
end
