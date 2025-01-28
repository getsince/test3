defmodule Since.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Ecto.Multi

  require Logger

  alias Since.{Repo, Media, Bot, Chats}

  alias Since.Accounts.{
    User,
    Profile,
    UserToken,
    UserReport,
    APNSDevice,
    GenderPreference,
    AppleSignIn,
    OnboardingEvent,
    AcquisitionChannel
  }

  alias Since.Games.ComplimentLimit

  alias Since.PushNotifications.DispatchJob

  @pubsub Since.PubSub
  @topic "__a"

  defp pubsub_user_topic(user_id) when is_binary(user_id) do
    @topic <> ":u:" <> String.downcase(user_id)
  end

  def subscribe_for_user(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, pubsub_user_topic(user_id))
  end

  defp broadcast_for_user(user_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, pubsub_user_topic(user_id), message)
  end

  # def subscribe_to_new_users do
  #   Phoenix.PubSub.subscribe(Since.PubSub, "new_users")
  # end

  # def notify_subscribers({:ok, %User{}}, [:new, :user]) do
  #   Phoenix.PubSub.broadcast()
  # end

  ## Database getters

  def get_user!(id), do: Repo.get!(User, id)

  def user_onboarded?(id) do
    User
    |> where(id: ^id)
    |> where([u], not is_nil(u.onboarded_at))
    |> Repo.exists?()
  end

  ## User registration

  def register_user_with_apple_id(attrs, now \\ DateTime.utc_now()) do
    now = DateTime.truncate(now, :second)

    Multi.new()
    |> Multi.insert(:user, User.apple_id_registration_changeset(%User{}, attrs))
    |> add_profile(now)
    |> Multi.run(:onboard_nag, fn _repo, %{user: %User{id: user_id}} ->
      job =
        DispatchJob.new(
          %{"type" => "complete_onboarding", "user_id" => user_id},
          scheduled_at: _in_24h = DateTime.add(now, 24 * 3600)
        )

      Oban.insert(job)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user, profile: profile}} ->
        m = "new user #{user.id}"
        Logger.warning(m)
        Bot.async_post_message(m)

        {:ok, %User{user | profile: profile}}

      {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp add_profile(multi, now) do
    multi
    |> Multi.insert(
      :profile,
      fn %{user: user} ->
        %Profile{user_id: user.id, last_active: DateTime.truncate(now, :second)}
      end,
      returning: [:hidden?]
    )
  end

  def update_last_active(user_id, now \\ DateTime.utc_now()) do
    now = DateTime.truncate(now, :second)

    Profile
    |> where(user_id: ^user_id)
    |> Repo.update_all(set: [last_active: now])
  end

  def update_location(user_id, location) do
    Profile
    |> where(user_id: ^user_id)
    |> Repo.update_all(set: [location: location, h3: Since.Geo.point_to_h3(location)])
  end

  def update_address(user_id, address) do
    Profile
    |> where(user_id: ^user_id)
    |> Repo.update_all(set: [address: address])
    |> case do
      {1, _} -> :ok
      _ -> :error
    end
  end

  def set_premium(user_id, premium) do
    m = "setting premium for user #{user_id} to #{premium}"
    Logger.warning(m)
    Bot.async_post_message(m)

    Multi.new()
    |> Multi.update_all(:set_premium, Profile |> where(user_id: ^user_id),
      set: [premium: premium]
    )
    |> Multi.run(:maybe_remove_compliment_limit, fn repo, _changes ->
      if premium do
        result = ComplimentLimit |> where(user_id: ^user_id) |> repo.delete_all()
        {:ok, result}
      else
        {:ok, nil}
      end
    end)
    |> Repo.transaction()
  end

  def save_acquisition_channel(user_id, channel) do
    Repo.insert!(%AcquisitionChannel{user_id: user_id, channel: channel})
    :ok
  end

  defp ensure_has_profile(%User{profile: %Profile{}} = user), do: user

  defp ensure_has_profile(%User{profile: nil} = user) do
    profile =
      Repo.insert!(%Profile{
        user_id: user.id,
        last_active: DateTime.truncate(DateTime.utc_now(), :second)
      })

    %User{user | profile: profile}
  end

  @spec login_or_register_user_with_apple_id(String.t()) ::
          {:ok, %User{profile: %Profile{}}}
          | {:error, :invalid_key_id | :invalid_token | Ecto.Changeset.t()}
  def login_or_register_user_with_apple_id(id_token) do
    case AppleSignIn.fields_from_token(id_token) do
      {:ok, %{user_id: apple_id, email: email}} ->
        get_or_register_user_with_apple_id(apple_id, email)

      {:error, _reason} = failure ->
        failure
    end
  end

  # TODO in one transaction
  defp get_or_register_user_with_apple_id(apple_id, email) do
    user = get_user_by_apple_id_updating_email(apple_id, email)

    if user do
      {:ok, ensure_has_profile(user)}
    else
      register_user_with_apple_id(%{apple_id: apple_id, email: email})
    end
  end

  defp get_user_by_apple_id_updating_email(apple_id, nil) do
    User
    |> where(apple_id: ^apple_id)
    |> select([u], u)
    |> Repo.one()
    |> case do
      nil -> nil
      user -> Repo.preload(user, :profile)
    end
  end

  defp get_user_by_apple_id_updating_email(apple_id, email) do
    User
    |> where(apple_id: ^apple_id)
    |> select([u], u)
    |> Repo.update_all(set: [email: email])
    |> case do
      {1, [user]} -> Repo.preload(user, :profile)
      {0, _} -> nil
    end
  end

  # TODO test
  def report_user(from_user_id, on_user_id, reason) do
    {reported_user_name, story, _quality, _date} = name_story_quality_date(on_user_id)
    story_string = story_to_string(story)
    {from_user_name, _story, _quality, _date} = name_story_quality_date(from_user_id)

    m =
      "user report from #{from_user_name} (#{from_user_id}) on #{reported_user_name} (#{on_user_id}), reason: #{reason}, story of reported: #{story_string}"

    Logger.warning(m)
    Bot.async_post_message(m)

    report_changeset =
      %UserReport{from_user_id: from_user_id, on_user_id: on_user_id}
      |> cast(%{reason: reason}, [:reason])
      |> validate_required([:reason])
      |> validate_length(:reason, max: 500)

    Multi.new()
    |> Multi.insert(:report, report_changeset)
    |> Chats.delete_chat_multi(from_user_id, on_user_id)
    |> Repo.transaction()
    |> case do
      {:ok, changes} ->
        Chats.notify_delete_chat_changes(changes)
        :ok

      {:error, :report, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp block_user_q(user_id) do
    User
    |> where(id: ^user_id)
    |> update([u], set: [blocked_at: fragment("now()")])
  end

  def block_user(user_id) do
    Multi.new()
    |> Multi.run(:block, fn repo, _changes ->
      user_id |> block_user_q() |> repo.update_all([])

      Profile
      |> where(user_id: ^user_id)
      |> repo.update_all(set: [hidden?: true])

      {:ok, nil}
    end)
    |> delete_all_chats(user_id)
    |> Repo.transaction()
    |> case do
      {:ok, _changes} ->
        tokens = UserToken |> where(user_id: ^user_id) |> select([t], t.token) |> Repo.all()

        for token <- tokens, do: SinceWeb.UserAuth.disconnect_mobile_user(token)

        :ok
    end
  end

  def unblock_user(user_id) do
    Multi.new()
    |> Multi.update_all(
      :unblock,
      User |> where(id: ^user_id) |> update(set: [blocked_at: nil]),
      []
    )
    |> Multi.update(:unhide, fn _changes ->
      %Profile{user_id: user_id} |> Ecto.Changeset.change(hidden?: false)
    end)
    |> Repo.transaction()
  end

  def hide_user(user_id) do
    {:ok, _profile} =
      %Profile{user_id: user_id}
      |> cast(%{hidden?: true}, [:hidden?])
      |> Repo.update()

    :ok
  end

  defp delete_all_chats(multi, user_id) do
    Multi.run(multi, :delete_chats, fn repo, _changes ->
      deleted_chats =
        Since.Chats.Chat
        |> where([c], c.user_id_1 == ^user_id or c.user_id_2 == ^user_id)
        |> repo.all()
        |> Enum.map(fn %Chats.Chat{user_id_1: uid1, user_id_2: uid2} ->
          [mate] = [uid1, uid2] -- [user_id]
          Since.Chats.delete_chat(user_id, mate)
        end)

      {:ok, deleted_chats}
    end)
  end

  defp name_story_quality_date(user_id) do
    {name, story} =
      Profile
      |> where(user_id: ^user_id)
      |> select([p], {p.name, p.story})
      |> Repo.one!()

    quality =
      case story do
        nil ->
          false

        _ ->
          if length(story) > 2 do
            true
          else
            labels_count = story |> Enum.count(fn page -> length(page["labels"]) end)

            if labels_count > 7 do
              true
            else
              false
            end
          end
      end

    date = User |> where(id: ^user_id) |> select([u], u.inserted_at) |> Repo.one!()

    {name, story, quality, date}
  end

  defp story_to_string(story) do
    if is_list(story) do
      photo_urls =
        Enum.map(story, fn p -> p["background"]["s3_key"] end)
        |> Enum.filter(&(!is_nil(&1)))
        |> Enum.flat_map(fn k ->
          ["https://since-when-are-you-happy.s3.eu-north-1.amazonaws.com/" <> k, " "]
        end)

      labels =
        Enum.map(story, fn p ->
          Enum.map(p["labels"], fn l ->
            l["value"] || l["answer"] || l["artist"] || l["question"]
          end)
          |> Enum.filter(&(!is_nil(&1)))
          |> Enum.flat_map(fn l -> [l, ", "] end)
        end)
        |> Enum.filter(&(!is_nil(&1)))

      "photos: #{photo_urls}, labels: #{labels}"
    else
      ""
    end
  end

  defp address_to_string(address) do
    case address["en_US"] do
      nil -> "no en_US address"
      %{"city" => city} -> city
      %{"state" => state} -> state
      %{"country" => country} -> country
      %{"name" => name} -> name
      a -> a
    end
  end

  # TODO deactivate session
  def delete_user(user_id, reason) do
    {name, story, quality, date} = name_story_quality_date(user_id)
    story_string = story_to_string(story)

    m =
      if quality do
        "deleted quality user #{name}, reason: #{reason}, registration date #{date}, (#{user_id}), #{story_string}"
      else
        "deleted user #{name}, reason: #{reason}, registration date #{date}, (#{user_id}), #{story_string}"
      end

    Logger.warning(m)
    Bot.async_post_silent_message(m)

    Multi.new()
    |> delete_all_chats(user_id)
    |> Multi.run(:session_tokens, fn _repo, _changes ->
      tokens = UserToken |> where(user_id: ^user_id) |> select([ut], ut.token) |> Repo.all()
      {:ok, tokens}
    end)
    |> Multi.run(:delete_user, fn _repo, _changes ->
      {1, _} =
        User
        |> where(id: ^user_id)
        |> Repo.delete_all()

      {:ok, true}
    end)
    |> Repo.transaction()
  end

  # apns

  defp default_apns_topic do
    Since.PushNotifications.APNS.default_topic()
  end

  defp with_base16_encoded_apns_device_id(devices) when is_list(devices) do
    Enum.map(devices, &with_base16_encoded_apns_device_id/1)
  end

  defp with_base16_encoded_apns_device_id(%APNSDevice{device_id: device_id} = device) do
    %APNSDevice{device | device_id: Base.encode16(device_id)}
  end

  def save_apns_device_id(user_id, token, device_id, extra \\ []) do
    %UserToken{id: token_id} = token |> UserToken.token_and_context_query("mobile") |> Repo.one!()

    prev_device_q =
      APNSDevice
      |> where([d], d.user_id == ^user_id and d.token_id == ^token_id)
      |> or_where(device_id: ^device_id)

    Repo.transaction(fn ->
      Repo.delete_all(prev_device_q)

      Repo.insert!(%APNSDevice{
        user_id: user_id,
        token_id: token_id,
        device_id: device_id,
        locale: extra[:locale],
        env: extra[:env],
        topic: extra[:topic] || default_apns_topic()
      })
    end)

    :ok
  end

  @spec list_apns_devices() :: [%APNSDevice{}]
  def list_apns_devices() do
    APNSDevice |> Repo.all() |> with_base16_encoded_apns_device_id()
  end

  @spec list_apns_devices([Ecto.UUID.t()]) :: [%APNSDevice{}]
  def list_apns_devices(user_ids) when is_list(user_ids) do
    APNSDevice
    |> where([d], d.user_id in ^user_ids)
    |> Repo.all()
    |> with_base16_encoded_apns_device_id()
  end

  @spec list_apns_devices(Ecto.UUID.t()) :: [%APNSDevice{}]
  def list_apns_devices(user_id) do
    APNSDevice
    |> where(user_id: ^user_id)
    |> Repo.all()
    |> with_base16_encoded_apns_device_id()
  end

  @doc "remove_apns_device(device_id_base_16)"
  def remove_apns_device(device_id) do
    APNSDevice
    |> where(device_id: ^Base.decode16!(device_id))
    |> Repo.delete_all()
  end

  ## Session

  @doc """
  Generates a session token for a user.
  """
  def generate_user_session_token(%User{id: user_id}, context) do
    generate_user_session_token(user_id, context)
  end

  def generate_user_session_token(user_id, context) when is_binary(user_id) do
    {token, user_token} = UserToken.build_token(user_id, context)
    Repo.insert!(user_token)
    token
  end

  def list_user_session_tokens(user_id, context) do
    user_id
    |> UserToken.user_and_contexts_query(context)
    |> order_by([t], desc: t.id)
    |> Repo.all()
    |> Enum.map(fn %UserToken{token: raw_token} = t ->
      %Since.Accounts.UserToken{t | token: UserToken.encoded_token(raw_token)}
    end)
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token, context) do
    get_user_by_session_token_and_update_version(token, nil, context)
  end

  # TODO split update, only do if old_version != new_version
  def get_user_by_session_token_and_update_version(token, version, context) do
    {:ok, query} =
      case context do
        "session" -> UserToken.verify_session_token_query(token)
        "mobile" -> UserToken.verify_mobile_token_query(token)
      end

    if version do
      case Repo.update_all(query, set: [version: version]) do
        {1, [user]} -> user
        {0, _} -> nil
      end
    else
      Repo.one(query)
    end
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token, context) do
    Repo.delete_all(UserToken.token_and_context_query(token, context))
    :ok
  end

  def list_all_users_with_session_tokens do
    UserToken
    |> join(:inner, [t], u in User, on: t.user_id == u.id)
    |> select([t, u], %{
      token: %{value: t.token, inserted_at: t.inserted_at},
      user: %{id: u.id, apple_id: u.apple_id}
    })
    |> Repo.all()
    |> Enum.group_by(
      fn %{user: user} -> user end,
      fn %{token: %{value: value, inserted_at: inserted_at}} ->
        %{token: UserToken.encoded_token(value), inserted_at: inserted_at}
      end
    )
  end

  def photo_upload_form(content_type) do
    Media.sign_form_upload(
      key: Ecto.UUID.generate(),
      content_type: content_type,
      max_file_size: 8_000_000,
      expires_in: :timer.hours(1),
      # TODO private
      acl: "public-read"
    )
  end

  def photo_s3_url do
    Media.user_s3_url()
  end

  def media_upload_form(content_type) do
    Media.sign_form_upload(
      Media.media_bucket(),
      key: Ecto.UUID.generate(),
      content_type: content_type,
      # 50 MB
      max_file_size: 50_000_000,
      expires_in: :timer.hours(1),
      acl: "public-read"
    )
  end

  def media_s3_url do
    Media.media_s3_url()
  end

  def get_profile!(%User{id: user_id}) do
    get_profile!(user_id)
  end

  def get_profile!(user_id) when is_binary(user_id) do
    profile =
      Profile
      |> where([p], p.user_id == ^user_id)
      |> Repo.one!()

    gender_preference =
      GenderPreference
      |> where([g], g.user_id == ^user_id)
      |> select([g], g.gender)
      |> Repo.all()

    %Profile{profile | gender_preference: gender_preference}
  end

  def onboard_profile(user_id, attrs) do
    # TODO remove
    attrs = for {k, v} <- attrs, do: {to_string(k), v}, into: %{}

    attrs =
      case attrs["gender_preference"] do
        nil -> Map.put(attrs, "gender_preference", ["M", "F", "N"])
        _ -> attrs
      end

    Multi.new()
    |> Multi.run(:user, fn repo, _changes ->
      user = repo.get!(User, user_id)

      if user.onboarded_at do
        {:error, :already_onboarded}
      else
        {:ok, repo.preload(user, :profile)}
      end
    end)
    |> Multi.update(:profile, fn %{user: %{profile: profile}} ->
      Profile.changeset(profile, attrs, validate_required?: true)
    end)
    |> maybe_update_profile_gender_preference(user_id, attrs)
    |> Multi.run(:mark_onboarded, fn repo, %{user: user} ->
      {1, nil} =
        User
        |> where(id: ^user.id)
        |> update([u], set: [onboarded_at: fragment("now()")])
        |> repo.update_all([])

      {:ok, nil}
    end)
    |> Multi.run(:show_profile, fn _repo, %{user: user} ->
      {count, nil} = maybe_unhide_profile_with_story(user.id)

      if count >= 1 do
        maybe_mark_onboarded_with_story(user.id)
      end

      {:ok, count >= 1}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, changes} ->
        %{user: user, profile: %Profile{} = profile, gender_preference: genders} = changes
        story_string = story_to_string(profile.story)
        address_string = address_to_string(profile.address)

        m =
          "user #{profile.name} (#{user.id}) from #{address_string} onboarded with story #{story_string}"

        Logger.warning(m)
        Bot.async_post_message(m)

        {:ok, %Profile{profile | gender_preference: genders, hidden?: false}}

      {:error, :user, :already_onboarded, _changes} ->
        {:error, :already_onboarded}

      {:error, :profile, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end

    # |> notify_subscribers([:user, :new])
  end

  def update_profile(user_id, attrs) do
    Logger.warning("user #{user_id} updates profile with #{inspect(attrs)}")

    Multi.new()
    |> Multi.run(:old_profile, fn _repo, _changes -> {:ok, Repo.get!(Profile, user_id)} end)
    |> Multi.update(
      :profile,
      fn %{old_profile: profile} -> Profile.changeset(profile, attrs) end,
      returning: true
    )
    |> maybe_update_profile_gender_preference(user_id, attrs)
    |> Multi.run(:maybe_unhide, fn _repo, %{profile: profile} ->
      has_story? = !!profile.story
      hidden? = profile.hidden?

      result =
        if hidden? and has_story? do
          result = {count, _} = maybe_unhide_profile_with_story(profile.user_id)

          if count >= 1 do
            maybe_mark_onboarded_with_story(profile.user_id)
          end

          result
        end

      {:ok, result}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, changes} ->
        %{profile: profile, gender_preference: genders} = changes

        broadcast_for_user(
          profile.user_id,
          {__MODULE__, :feed_filter_updated,
           %Since.Feeds.FeedFilter{
             genders: genders,
             min_age: profile.min_age,
             max_age: profile.max_age,
             distance: profile.distance
           }}
        )

        {:ok, %Profile{profile | gender_preference: genders}}

      {:error, :profile, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  defp maybe_update_profile_gender_preference(multi, user_id, attrs)
       when is_map(attrs) do
    maybe_update_profile_gender_preference(
      multi,
      user_id,
      attrs[:gender_preference] || attrs["gender_preference"]
    )
  end

  # TODO test
  defp maybe_update_profile_gender_preference(multi, user_id, new_genders)
       when is_list(new_genders) do
    Multi.run(multi, :gender_preference, fn _repo, _changes ->
      old_genders =
        GenderPreference
        |> where(user_id: ^user_id)
        |> select([p], p.gender)
        |> Repo.all()

      to_add = new_genders -- old_genders
      to_remove = old_genders -- new_genders

      GenderPreference
      |> where(user_id: ^user_id)
      |> where([p], p.gender in ^to_remove)
      |> Repo.delete_all()

      Repo.insert_all(
        GenderPreference,
        Enum.map(to_add, fn g -> %{user_id: user_id, gender: g} end)
      )

      {:ok, new_genders}
    end)
  end

  defp maybe_update_profile_gender_preference(multi, user_id, _attrs) do
    Multi.run(multi, :gender_preference, fn _repo, _changes ->
      genders =
        GenderPreference
        |> where(user_id: ^user_id)
        |> select([p], p.gender)
        |> Repo.all()

      {:ok, genders}
    end)
  end

  def get_location_gender_premium_hidden?(user_id) do
    Profile
    |> where(user_id: ^user_id)
    |> select([p], {p.location, p.gender, p.premium, p.hidden?})
    |> Repo.one!()
  end

  def list_gender_preference(user_id) do
    GenderPreference
    |> where(user_id: ^user_id)
    |> select([p], p.gender)
    |> Repo.all()
  end

  defp maybe_unhide_profile_with_story(user_id) when is_binary(user_id) do
    Profile
    |> where(user_id: ^user_id)
    |> where([p], not is_nil(p.story))
    |> join(:inner, [p], u in User, on: u.id == p.user_id)
    |> where([_, u], not is_nil(u.onboarded_at))
    |> where([_, u], is_nil(u.blocked_at))
    |> Repo.update_all(set: [hidden?: false])
  end

  defp maybe_mark_onboarded_with_story(user_id) do
    User
    |> where(id: ^user_id)
    |> where([u], is_nil(u.onboarded_with_story_at))
    |> update([u], set: [onboarded_with_story_at: fragment("now()")])
    |> Repo.update_all([])
  end

  def schedule_upgrade_app_push(user_id) do
    job = DispatchJob.new(%{"type" => "upgrade_app", "user_id" => user_id})
    Oban.insert(job)
  end

  def save_onboarding_event(user_id, timestamp, stage, event) do
    {:ok, datetime, 0} = DateTime.from_iso8601(timestamp)

    Repo.insert!(%OnboardingEvent{
      timestamp: datetime,
      user_id: user_id,
      stage: stage,
      event: event
    })

    if event == "finished", do: count_onboarding_stats(user_id)

    :ok
  end

  def count_onboarding_stats(user_id) do
    events =
      OnboardingEvent |> where(user_id: ^user_id) |> order_by(asc: :timestamp) |> Repo.all()

    feed_events = events |> Enum.filter(fn %OnboardingEvent{stage: stage} -> stage == "feed" end)

    fields_events =
      events |> Enum.filter(fn %OnboardingEvent{stage: stage} -> stage == "fields" end)

    story_events =
      events |> Enum.filter(fn %OnboardingEvent{stage: stage} -> stage == "story" end)

    timestamps = Enum.map(events, fn %OnboardingEvent{timestamp: timestamp} -> timestamp end)
    {start, finish} = timestamps |> Enum.min_max()
    total = Float.ceil(DateTime.diff(finish, start) / 60, 2)

    dummy_event = %OnboardingEvent{
      timestamp: DateTime.utc_now(),
      user_id: user_id,
      stage: "feed",
      event: "background"
    }

    {_event, active} =
      Enum.reduce(events, {dummy_event, 0}, fn event, {previous_event, time_acc} ->
        time =
          if previous_event.event == "background" do
            time_acc
          else
            time_acc + DateTime.diff(event.timestamp, previous_event.timestamp)
          end

        {event, time}
      end)

    active = Float.ceil(active / 60, 2)

    sessions =
      1 + Enum.count(events, fn %OnboardingEvent{event: event} -> event == "background" end)

    feed_finish =
      fields_events
      |> Enum.map(fn %OnboardingEvent{timestamp: timestamp} -> timestamp end)
      |> Enum.min()

    feed_total = Float.ceil(DateTime.diff(feed_finish, start) / 60, 2)

    {feed_event, feed_active} =
      Enum.reduce(feed_events, {dummy_event, 0}, fn event, {previous_event, time_acc} ->
        time =
          if previous_event.event == "background" do
            time_acc
          else
            time_acc + DateTime.diff(event.timestamp, previous_event.timestamp)
          end

        {event, time}
      end)

    feed_active =
      Float.ceil((feed_active + DateTime.diff(feed_finish, feed_event.timestamp)) / 60, 2)

    feed_sessions =
      1 + Enum.count(feed_events, fn %OnboardingEvent{event: event} -> event == "background" end)

    fields_finish =
      story_events
      |> Enum.map(fn %OnboardingEvent{timestamp: timestamp} -> timestamp end)
      |> Enum.min()

    fields_total = Float.ceil(DateTime.diff(fields_finish, feed_finish) / 60, 2)

    {fields_event, fields_active} =
      Enum.reduce(fields_events, {dummy_event, 0}, fn event, {previous_event, time_acc} ->
        time =
          if previous_event.event == "background" do
            time_acc
          else
            time_acc + DateTime.diff(event.timestamp, previous_event.timestamp)
          end

        {event, time}
      end)

    fields_active =
      Float.ceil((fields_active + DateTime.diff(fields_finish, fields_event.timestamp)) / 60, 2)

    fields_sessions =
      1 +
        Enum.count(fields_events, fn %OnboardingEvent{event: event} -> event == "background" end)

    story_total = Float.ceil(DateTime.diff(finish, fields_finish) / 60, 2)

    {story_event, story_active} =
      Enum.reduce(story_events, {dummy_event, 0}, fn event, {previous_event, time_acc} ->
        time =
          if previous_event.event == "background" do
            time_acc
          else
            time_acc + DateTime.diff(event.timestamp, previous_event.timestamp)
          end

        {event, time}
      end)

    story_active =
      Float.ceil((story_active + DateTime.diff(finish, story_event.timestamp)) / 60, 2)

    story_sessions =
      1 + Enum.count(story_events, fn %OnboardingEvent{event: event} -> event == "background" end)

    m =
      "onboarding for #{user_id} took #{total} minutes (#{active} active) in #{sessions} session(s)
    \nfeed: #{feed_total} minutes (#{feed_active} active) in #{feed_sessions} session(s)
    \nfields: #{fields_total} minutes (#{fields_active} active) in #{fields_sessions} session(s)
    \nstory: #{story_total} minutes (#{story_active} active) in #{story_sessions} session(s)"

    Bot.async_post_message(m)
  end
end
