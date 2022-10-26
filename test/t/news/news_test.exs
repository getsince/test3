defmodule T.NewsTest do
  use T.DataCase, async: true

  alias T.News

  @previous_version "7.1.8"
  @current_version "8.0.0"

  describe "list_news/1" do
    test "to old user" do
      old_uid = "0000017c-14c7-9745-0242-ac1100020000"
      news = News.list_news(old_uid, @current_version)
      assert length(news) == 1
    end

    test "to just registered user" do
      just_registered_uid = Ecto.Bigflake.UUID.generate()
      news = News.list_news(just_registered_uid, @current_version)
      assert length(news) == 0
    end

    test "to users of previous version" do
      old_uid = "0000017c-14c7-9745-0242-ac1100020000"
      news = News.list_news(old_uid, @previous_version)
      assert length(news) == 0
    end
  end
end
