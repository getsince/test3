defmodule T.NewsTest do
  use T.DataCase, async: true

  alias T.News

  describe "list_news/1" do
    test "to old user" do
      old_uid = "0000017c-14c7-9745-0242-ac1100020000"
      news = News.list_news(old_uid)
      assert length(news) == 2
    end

    test "to not so old user" do
      not_so_old_uid = "0000017f-b531-3203-0e40-1573d1920000"
      news = News.list_news(not_so_old_uid)
      assert length(news) == 1
    end
  end
end
