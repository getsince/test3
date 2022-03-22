defmodule T.NewsTest do
  use T.DataCase, async: true

  alias T.News

  describe "list_news/3" do
    setup do
      me = onboarded_user()

      news = [
        %{id: 10, story: []},
        %{id: 11, story: []},
        %{id: 12, version: "10.0.0", story: []}
      ]

      {:ok, me: me, news: news}
    end

    test "all news are returned", %{me: me, news: news} do
      version = Version.parse!("10.0.0")

      assert news == News.list_news(me.id, version, news)
    end

    test "update story page is added to news with higher version", %{me: me, news: news} do
      version = Version.parse!("6.0.0")

      [_n1, _n2, n3] = News.list_news(me.id, version, news)

      assert length(n3.story) == 1
    end
  end
end
