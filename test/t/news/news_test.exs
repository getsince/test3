defmodule T.NewsTest do
  use T.DataCase, async: true

  alias T.News

  @previous_version "6.1.0"
  @current_version "6.1.2"

  describe "list_news/1" do
    test "to old user" do
      old_uid = "0000017c-14c7-9745-0242-ac1100020000"
      news = News.list_news(old_uid, @current_version)
      assert length(news) == 2
    end

    test "to not so old user" do
      not_so_old_uid = "0000017f-f572-c244-0aa1-83b884ba0000"
      news = News.list_news(not_so_old_uid, @current_version)
      assert length(news) == 1
    end

    test "to users of previous version" do
      old_uid = "0000017c-14c7-9745-0242-ac1100020000"
      news = News.list_news(old_uid, @previous_version)
      assert length(news) == 1
    end
  end
end
