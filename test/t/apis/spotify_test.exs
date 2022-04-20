defmodule T.SpotifyTest do
  use ExUnit.Case, async: true
  alias T.Spotify

  describe "current_token" do
    @tag :integration
    test "fetches a token from spotify" do
      assert {:ok, _token} = Spotify.current_token()
    end
  end
end
