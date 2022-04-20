defmodule T.SpotifyTest do
  use T.DataCase, async: true
  alias T.Spotify

  describe "current_token" do
    test "fetches a token from spotify" do
      assert {:ok, _token} = Spotify.current_token()
    end
  end
end
