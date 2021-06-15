defmodule T.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use T.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias T.Repo

      import Ecto
      import Ecto.{Changeset, Query}
      import T.{DataCase, Factory}
      import Assertions
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(T.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(T.Repo, {:shared, self()})
    end

    Mox.stub_with(MockBot, StubBot)

    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  alias T.Repo
  alias T.Feeds.{SeenProfile, ProfileLike, ProfileDislike}
  alias T.Accounts.Profile

  import Ecto.Query
  import Assertions
  import T.Factory

  def assert_seen(opts) do
    assert SeenProfile |> where(^opts) |> Repo.one!()
  end

  def assert_liked(opts) do
    assert ProfileLike |> where(^opts) |> Repo.one!()
  end

  def assert_disliked(opts) do
    assert ProfileDislike |> where(^opts) |> Repo.one!()
  end

  def assert_hidden(user_ids) do
    Profile
    |> where([p], p.user_id in ^user_ids)
    |> Repo.all()
    |> Enum.each(fn profile ->
      assert profile.hidden?
    end)
  end

  def refute_hidden(user_ids) do
    Profile
    |> where([p], p.user_id in ^user_ids)
    |> Repo.all()
    |> Enum.each(fn profile ->
      refute profile.hidden?
    end)
  end

  def times_liked(user_id) do
    Profile
    |> where(user_id: ^user_id)
    |> select([p], p.times_liked)
    |> Repo.one()
  end

  def assert_feed_has_profile(feed, profile) do
    feed_ids = Enum.map(feed, & &1.user_id)
    assert profile.user_id in feed_ids
  end

  def most_liked(profiles, likes) do
    profiles
    |> Enum.shuffle()
    |> Enum.zip(likes)
    |> Enum.map(fn {profile, likes} ->
      {1, nil} =
        Profile
        |> where(user_id: ^profile.user_id)
        |> Repo.update_all(set: [times_liked: likes])

      %Profile{profile | times_liked: likes}
    end)
  end

  def personality_overlap(profiles, me, scores) do
    profiles
    |> Enum.shuffle()
    |> Enum.zip(scores)
    |> Enum.map(fn {profile, score} ->
      insert(:personality_overlap,
        score: score,
        user_id_1: profile.user_id,
        user_id_2: me.user_id
      )

      profile
    end)
  end

  def assert_reasons(feed, reasons) do
    assert_lists_equal(Enum.map(feed, & &1.feed_reason), reasons)
  end

  def assert_unique_profiles(feed) do
    assert length(feed) == feed |> Enum.uniq_by(& &1.user_id) |> length()
  end
end
