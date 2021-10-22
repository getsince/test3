defmodule T.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Ecto.Multi

  require Logger

  alias T.{Repo, Media, Bot, Matches}

  alias T.Accounts.{
    User,
    Profile,
    UserToken,
    UserReport,
    APNSDevice,
    PushKitDevice,
    GenderPreference,
    AppleSignIn
  }

  # def subscribe_to_new_users do
  #   Phoenix.PubSub.subscribe(T.PubSub, "new_users")
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

  @doc false
  def register_user_with_apple_id(attrs, now \\ DateTime.utc_now()) do
    Multi.new()
    |> Multi.insert(:user, User.apple_id_registration_changeset(%User{}, attrs))
    |> add_profile_and_transact(now)
  end

  defp add_profile_and_transact(multi, now) do
    multi
    |> Multi.insert(
      :profile,
      fn %{user: user} ->
        %Profile{user_id: user.id, last_active: DateTime.truncate(now, :second)}
      end,
      returning: [:hidden?]
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user, profile: profile}} ->
        Logger.warn("new user #{user.apple_id}")
        Bot.async_post_message("new user #{user.apple_id}")
        {:ok, %User{user | profile: profile}}

      {:error, :user, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  def update_last_active(user_id, time \\ DateTime.utc_now()) do
    time = DateTime.truncate(time, :second)

    Profile
    |> where(user_id: ^user_id)
    |> Repo.update_all(set: [last_active: time])
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
    if u = get_user_by_apple_id_updating_email(apple_id, email) do
      {:ok, ensure_has_profile(u)}
    else
      register_user_with_apple_id(%{apple_id: apple_id, email: email})
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
    Logger.warn("user #{from_user_id} reported #{on_user_id} with reason #{reason}")

    report_changeset =
      %UserReport{from_user_id: from_user_id, on_user_id: on_user_id}
      |> cast(%{reason: reason}, [:reason])
      |> validate_required([:reason])
      |> validate_length(:reason, max: 500)

    Multi.new()
    |> Multi.insert(:report, report_changeset)
    |> maybe_block(on_user_id)
    |> Matches.unmatch_multi(from_user_id, on_user_id)
    |> Repo.transaction()
    |> case do
      {:ok, changes} ->
        Matches.notify_unmatch_changes(changes)
        :ok

      {:error, :report, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  # TODO test, unmatch
  defp maybe_block(multi, reported_user_id) do
    Multi.run(multi, :block, fn repo, _changes ->
      reports_count =
        UserReport |> where(on_user_id: ^reported_user_id) |> select([r], count()) |> Repo.one!()

      blocked? =
        if reports_count >= 3 do
          reported_user_id
          |> block_user_q()
          |> repo.update_all([])

          m = "blocking user #{reported_user_id} due to #reports >= 3"
          Logger.warn(m)
          Bot.async_post_silent_message(m)

          Profile
          |> where(user_id: ^reported_user_id)
          |> repo.update_all(set: [hidden?: true])
        end

      {:ok, !!blocked?}
    end)
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
    |> unmatch_all(user_id)
    |> Repo.transaction()
    |> case do
      {:ok, _changes} -> :ok
    end
  end

  defp unmatch_all(multi, user_id) do
    Multi.run(multi, :unmatch, fn repo, _changes ->
      unmatches =
        T.Matches.Match
        |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
        |> select([m], m.id)
        |> repo.all()
        |> Enum.map(fn match_id ->
          T.Matches.unmatch_match(user_id, match_id)
        end)

      {:ok, unmatches}
    end)
  end

  # TODO deactivate session
  def delete_user(user_id) do
    delete_user_name =
      Profile
      |> where(user_id: ^user_id)
      |> select([p], p.name)
      |> Repo.one!()

    m = "deleted user #{user_id}, user name is #{delete_user_name}"

    Logger.warn(m)
    Bot.async_post_silent_message(m)

    Multi.new()
    |> unmatch_all(user_id)
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
    T.PushNotifications.APNS.default_topic()
  end

  defp with_base16_encoded_apns_device_id(devices) when is_list(devices) do
    Enum.map(devices, &with_base16_encoded_apns_device_id/1)
  end

  defp with_base16_encoded_apns_device_id(%PushKitDevice{device_id: device_id} = device) do
    %PushKitDevice{device | device_id: Base.encode16(device_id)}
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

  def save_pushkit_device_id(user_id, token, device_id, extra) do
    %UserToken{id: token_id} = token |> UserToken.token_and_context_query("mobile") |> Repo.one!()

    prev_device_q =
      PushKitDevice
      |> where([d], d.user_id == ^user_id and d.token_id == ^token_id)
      |> or_where(device_id: ^device_id)

    Repo.transaction(fn ->
      Repo.delete_all(prev_device_q)

      Repo.insert!(%PushKitDevice{
        user_id: user_id,
        token_id: token_id,
        device_id: device_id,
        env: extra[:env],
        topic: extra[:topic] || default_apns_topic()
      })
    end)

    :ok
  end

  @doc "remove_pushkit_device(device_id_base_16)"
  def remove_pushkit_device(device_id) do
    PushKitDevice
    |> where(device_id: ^Base.decode16!(device_id))
    |> Repo.delete_all()
  end

  @spec list_pushkit_devices(Ecto.UUID.t()) :: [%PushKitDevice{}]
  def list_pushkit_devices(user_id) when is_binary(user_id) do
    PushKitDevice
    |> where(user_id: ^user_id)
    |> Repo.all()
    |> with_base16_encoded_apns_device_id()
  end

  ## Session

  @doc """
  Generates a session token for a user.
  """
  def generate_user_session_token(user, context) do
    {token, user_token} = UserToken.build_token(user, context)
    Repo.insert!(user_token)
    token
  end

  def list_user_session_tokens(user_id, context) do
    user_id
    |> UserToken.user_and_contexts_query(context)
    |> order_by([t], desc: t.id)
    |> Repo.all()
    |> Enum.map(fn %UserToken{token: raw_token} = t ->
      %T.Accounts.UserToken{t | token: UserToken.encoded_token(raw_token)}
    end)
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token, context) do
    {:ok, query} =
      case context do
        "session" -> UserToken.verify_session_token_query(token)
        "mobile" -> UserToken.verify_mobile_token_query(token)
      end

    Repo.one(query)
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
      expires_in: :timer.hours(1)
    )
  end

  def photo_s3_url do
    Media.user_s3_url()
  end

  def get_profile!(%User{id: user_id}) do
    get_profile!(user_id)
  end

  def get_profile!(user_id) when is_binary(user_id) do
    Repo.get!(Profile, user_id)
  end

  def onboard_profile(%Profile{user_id: user_id} = profile, attrs) do
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
    |> update_profile_gender_preferences(profile)
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
      {:ok, count >= 1}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user, profile: %Profile{} = profile}} ->
        m = "user registered #{user.id}, user name is #{profile.name}"
        Logger.warn(m)
        Bot.async_post_message(m)
        {:ok, %Profile{profile | hidden?: false}}

      {:error, :user, :already_onboarded, _changes} ->
        {:error, :already_onboarded}

      {:error, :profile, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end

    # |> notify_subscribers([:user, :new])
  end

  def update_profile(%Profile{} = profile, attrs, opts \\ []) do
    Logger.warn("user #{profile.user_id} updates profile with #{inspect(attrs)}")

    Multi.new()
    |> Multi.update(:profile, Profile.changeset(profile, attrs, opts), returning: true)
    |> update_profile_gender_preferences(profile)
    |> Multi.run(:maybe_unhide, fn _repo, %{profile: profile} ->
      has_story? = !!profile.story
      hidden? = profile.hidden?
      result = if hidden? and has_story?, do: maybe_unhide_profile_with_story(profile.user_id)
      {:ok, result}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{profile: profile}} -> {:ok, profile}
      {:error, :profile, %Ecto.Changeset{} = changeset, _changes} -> {:error, changeset}
    end
  end

  # TODO test
  defp update_profile_gender_preferences(
         multi,
         %Profile{user_id: user_id, filters: %Profile.Filters{genders: [_ | _] = old_genders}}
       ) do
    Multi.run(multi, :update_profile_gender_preferences, fn _repo, %{profile: new_profile} ->
      %Profile{filters: %Profile.Filters{genders: new_genders}} = new_profile

      # TODO
      new_genders = new_genders || []

      to_add = new_genders -- old_genders
      to_remove = old_genders -- new_genders

      GenderPreference
      |> where(user_id: ^user_id)
      |> where([p], p.gender in ^to_remove)
      |> Repo.delete_all()

      insert_all_gender_preferences(to_add, user_id)

      {:ok, [to_add: to_add, to_remove: to_remove]}
    end)
  end

  defp update_profile_gender_preferences(multi, %Profile{user_id: user_id}) do
    Multi.run(multi, :update_profile_gender_preferences, fn _repo, %{profile: new_profile} ->
      %Profile{filters: %Profile.Filters{genders: new_genders}} = new_profile
      insert_all_gender_preferences(new_genders || [], user_id)
      {:ok, [to_add: new_genders, to_remove: []]}
    end)
  end

  defp insert_all_gender_preferences(genders, user_id) when is_list(genders) do
    Repo.insert_all(
      GenderPreference,
      Enum.map(genders, fn g -> %{user_id: user_id, gender: g} end)
    )
  end

  def get_location_and_gender!(user_id) do
    Profile
    |> where(user_id: ^user_id)
    |> select([p], {p.location, p.gender})
    |> Repo.one!()
  end

  def list_gender_preferences(user_id) do
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

  def profile_editor_tutorial(_id) do
    [
      %{
        "size" => [428, 926],
        "labels" => [
          %{
            "size" => [247.293, 44.052],
            "value" => "добавили твоё имя 👆",
            "center" => [142.3333282470703, 317.8333282470703],
            "rotation" => 0
          },
          %{
            "size" => [148.403, 56.516],
            "value" => "<REPLACE>",
            "answer" => "<REPLACE>",
            "center" => [221.00001525878906, 193.16668701171875],
            "question" => "name",
            "rotation" => 0
          },
          %{
            "size" => [181.71391118062405, 107.80452788116632],
            "value" => "перелистни\nна следующую\nстраницу 👉👉",
            "center" => [260.3333282470702, 611.1666870117186],
            "rotation" => -25.07355455145478
          }
        ],
        "background" => %{"color" => "#F97EB9"}
      },
      %{
        "size" => [428, 926],
        "labels" => [
          %{
            "size" => [142.66666666666666, 142.66666666666666],
            "value" => "Москва",
            "answer" => "Москва",
            "center" => [101.99999999999994, 255.66665649414062],
            "question" => "city",
            "rotation" => 0
          },
          %{
            "size" => [171.84924426813305, 47.188753122933925],
            "value" => "👈 это стикер",
            "center" => [297.6666564941406, 185.83334350585938],
            "rotation" => -22.602836861171024
          },
          %{
            "size" => [293.581, 44.052],
            "value" => "перетащи меня 👇 и удали",
            "center" => [207, 695.5],
            "rotation" => 0
          }
        ],
        "background" => %{"color" => "#5E50FC"}
      }
    ]
  end

  # ADMIN functions

  @spec current_admin_id :: Ecto.UUID.t()
  def current_admin_id do
    Application.fetch_env!(:t, :current_admin_id)
  end

  @spec is_admin?(%User{} | String.t()) :: boolean()
  def is_admin?(%User{id: user_id}) do
    is_admin?(user_id)
  end

  def is_admin?(user_id) when is_binary(user_id) do
    user_id == current_admin_id()
  end

  @spec admin_list_profiles_ordered_by_activity :: [%Profile{}]
  def admin_list_profiles_ordered_by_activity do
    Profile
    |> order_by(desc: :last_active)
    |> Repo.all()
  end
end
