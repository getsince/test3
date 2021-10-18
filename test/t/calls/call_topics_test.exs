defmodule T.CallTopicsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.CallTopics

  describe "call topics" do
    # TODO list of supported locales to ENVs?
    test "call topics for every locale has equal size" do
      locales = ["en", "ru"]

      en_locale_length = length(CallTopics.locale_topics("en"))

      for locale <- locales do
        assert en_locale_length == length(CallTopics.locale_topics(locale))
      end
    end
  end
end
