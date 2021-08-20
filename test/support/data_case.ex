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

  alias T.{Repo, Feeds}
  alias T.Feeds.{ProfileLike, ProfileDislike}
  alias T.Accounts.{User, Profile}

  import Ecto.Query

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

  def activate_sessions(users, reference) do
    Enum.map(users, &activate_session(&1, reference))
  end

  def activate_session(%User{id: user_id}, reference) do
    activate_session(user_id, reference)
  end

  def activate_session(%Profile{user_id: user_id}, reference) do
    activate_session(user_id, reference)
  end

  def activate_session(user_id, reference) when is_binary(user_id) do
    Feeds.activate_session(user_id, _duration = 60, reference)
  end
end
