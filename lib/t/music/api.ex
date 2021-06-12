defmodule T.Music.API do
  @behaviour T.Music

  # TODO don't leak tokens to logs
  @impl true
  def get_song(id) when is_binary(id) do
    url = "https://api.music.apple.com/v1/catalog/ru/songs/#{URI.encode_www_form(id)}"
    headers = [{"Authorization", "Bearer #{T.Music.token()}"}]
    req = Finch.build(:get, url, headers)
    {:ok, %Finch.Response{status: 200, body: body}} = Finch.request(req, T.Finch)
    Jason.decode!(body)
  end
end
