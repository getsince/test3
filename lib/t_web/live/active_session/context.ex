defmodule TWeb.ActiveSessionLive.Context do
  @moduledoc false
  import Ecto.{Query, Changeset}

  alias T.Accounts.{User, Profile}
  alias T.Feeds.{ActiveSession, FeedProfile}
  alias T.Matches.{Match}
  alias T.Calls.{Call, Invite}
  alias T.Repo

  def list_active_sessions do
    ActiveSession
    |> join(:inner, [s], p in FeedProfile, on: s.user_id == p.user_id)
    |> select([s, p], %{
      session_id: s.flake,
      user_id: p.user_id,
      user_name: p.name,
      expires_at: s.expires_at
    })
    |> Repo.all()
  end

  def list_user_options do
    FeedProfile
    |> select([p], {coalesce(p.name, type(p.user_id, :string)), p.user_id})
    |> Repo.all()
  end

  def activate_session(params) do
    {%{}, []}
    |> cast(params, [:user_id, :duration])
    |> validate_required([:user_id, :duration])
    |> validate_number(:duration, greater_than: 0)
  end

  def user_exists?(user_id) do
    User
    |> where(id: ^user_id)
    |> Repo.exists?()
  end

  def username(user_id) do
    Profile
    |> where(user_id: ^user_id)
    |> select([p], p.name)
    |> Repo.one()
  end

  # TODO timeslots, name
  def list_matches(user_id) do
    m1 =
      Match
      |> where(user_id_1: ^user_id)
      |> join(:left, [m], s in ActiveSession, on: m.user_id_2 == s.user_id)
      |> join(:inner, [m], p in FeedProfile, on: m.user_id_2 == p.user_id)
      |> select([m, s, p], %{
        user_id: m.user_id_2,
        session_id: s.flake,
        expires_at: s.expires_at,
        user_name: p.name,
        match: map(m, [:id, :inserted_at])
      })

    m2 =
      Match
      |> where(user_id_2: ^user_id)
      |> join(:left, [m], s in ActiveSession, on: m.user_id_1 == s.user_id)
      |> join(:inner, [m], p in FeedProfile, on: m.user_id_1 == p.user_id)
      |> select([m, s, p], %{
        user_id: m.user_id_1,
        session_id: s.flake,
        expires_at: s.expires_at,
        user_name: p.name,
        match: map(m, [:id, :inserted_at])
      })

    m1
    |> union_all(^m2)
    |> Repo.all()
  end

  def list_missed_calls(user_id) do
    Call
    |> where(called_id: ^user_id)
    |> where([c], is_nil(c.accepted_at))
    |> order_by(asc: :id)
    |> join(:inner, [c], p in FeedProfile, on: c.caller_id == p.user_id)
    |> join(:left, [c], s in ActiveSession, on: c.caller_id == s.user_id)
    |> select([c, p, s], %{
      user_id: c.caller_id,
      session_id: s.flake,
      expires_at: s.expires_at,
      user_name: p.name,
      call: map(c, [:id, :inserted_at, :ended_at])
    })
    |> Repo.all()
  end

  def list_invites(user_id) do
    Invite
    |> where(user_id: ^user_id)
    |> join(:inner, [i], p in FeedProfile, on: i.by_user_id == p.user_id)
    |> join(:inner, [i], s in ActiveSession, on: i.by_user_id == s.user_id)
    |> select([i, p, s], %{
      user_id: i.by_user_id,
      session_id: s.flake,
      expires_at: s.expires_at,
      user_name: p.name,
      invite: map(i, [:inserted_at])
    })
    |> Repo.all()
  end
end
