defmodule T.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  import T.Gettext

  alias T.{Repo, Media}

  alias T.Accounts.{
    User,
    Profile,
    UserToken,
    UserNotifier,
    UserReport,
    APNSDevice,
    PushKitDevice,
    GenderPreference
  }

  # def subscribe_to_new_users do
  #   Phoenix.PubSub.subscribe(T.PubSub, "new_users")
  # end

  # def notify_subscribers({:ok, %User{}}, [:new, :user]) do
  #   Phoenix.PubSub.broadcast()
  # end

  ## Database getters

  def get_user_by_phone_number(phone_number) when is_binary(phone_number) do
    User |> Repo.get_by(phone_number: phone_number) |> Repo.preload(:profile)
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_phone_number!(user_id) do
    User
    |> where(id: ^user_id)
    |> select([u], u.phone_number)
    |> Repo.one!()
  end

  def user_onboarded?(id) do
    User
    |> where(id: ^id)
    |> where([u], not is_nil(u.onboarded_at))
    |> Repo.exists?()
  end

  ## User registration

  @doc false
  def register_user(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:user, User.registration_changeset(%User{}, attrs))
    |> Ecto.Multi.insert(
      :profile,
      fn %{user: user} ->
        %Profile{
          user_id: user.id,
          last_active: DateTime.truncate(DateTime.utc_now(), :second)
        }
      end,
      returning: [:hidden?]
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user, profile: profile}} ->
        T.Bot.post_new_user(user.phone_number)
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

  def add_demo_phone(phone_number, code) do
    with {:ok, phone_number} <- formatted_phone_number(phone_number) do
      new = Map.put(demo_phones(), phone_number, code)
      Application.put_env(:t, :demo_phones, new)
      new
    end
  end

  def demo_phones do
    Application.get_env(:t, :demo_phones) || %{}
  end

  defp demo_phone?(phone_number) do
    phone_number in Map.keys(demo_phones())
  end

  defp demo_phone_code(phone_number) do
    Map.fetch!(demo_phones(), phone_number)
  end

  # TODO test when deleted
  # TODO in one transaction
  defp get_or_register_user(phone_number) do
    if u = get_user_by_phone_number(phone_number) do
      {:ok, ensure_has_profile(u)}
    else
      register_user(%{phone_number: phone_number})
    end
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

  @doc """
  Delivers the confirmation SMS instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(phone_number)
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_confirmation_instructions(phone_number) when is_binary(phone_number) do
    # TODO rate limit
    # TODO check if phone number belongs to someone deleted?
    with {:ok, phone_number} <- formatted_phone_number(phone_number) do
      if demo_phone?(phone_number) do
        {:ok, %{to: phone_number, body: nil}}
      else
        code = PasswordlessAuth.generate_code(phone_number, 4)
        UserNotifier.deliver_confirmation_instructions(phone_number, code)
      end
    end
  end

  @spec formatted_phone_number(String.t()) :: {:ok, String.t()} | {:error, :invalid_phone_number}
  def formatted_phone_number(phone_number) when is_binary(phone_number) do
    with {:ok, phone} <- ExPhoneNumber.parse(phone_number, "ru"),
         true <- ExPhoneNumber.is_valid_number?(phone) do
      {:ok, ExPhoneNumber.format(phone, :e164)}
    else
      _ -> {:error, :invalid_phone_number}
    end
  end

  def login_or_register_user(phone_number, code) do
    with {:format, {:ok, phone_number}} <- {:format, formatted_phone_number(phone_number)},
         {:code, :ok} <- {:code, verify_code(phone_number, code)},
         {:reg, {:ok, _user} = success} <- {:reg, get_or_register_user(phone_number)} do
      success
    else
      {:format, error} -> error
      {:code, error} -> error
      {:reg, error} -> error
    end
  end

  @spec verify_code(String.t(), String.t()) ::
          :ok | {:error, ExPhoneNumber.verification_failed_reason()}
  defp verify_code(phone_number, code) do
    if demo_phone?(phone_number) do
      if code == demo_phone_code(phone_number) do
        :ok
      else
        {:error, :incorrect_code}
      end
    else
      PasswordlessAuth.verify_code(phone_number, code)
    end
  end

  # TODO test
  def report_user(from_user_id, on_user_id, reason) do
    report_changeset =
      %UserReport{from_user_id: from_user_id, on_user_id: on_user_id}
      |> cast(%{reason: reason}, [:reason])
      |> validate_required([:reason])
      |> validate_length(:reason, max: 500)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:report, report_changeset)
    |> maybe_block_user_multi(on_user_id)
    |> Ecto.Multi.insert(
      :seen,
      %T.Feeds.SeenProfile{
        by_user_id: from_user_id,
        user_id: on_user_id
      },
      on_conflict: :nothing
    )
    |> Ecto.Multi.run(:unmatch, fn repo, _changes ->
      [u1, u2] = Enum.sort([from_user_id, on_user_id])

      match_id =
        T.Matches.Match
        |> where(user_id_1: ^u1)
        |> where(user_id_2: ^u2)
        |> select([m], m.id)
        |> repo.one()

      if match_id do
        T.Matches.unmatch(user: from_user_id, match: match_id)
      else
        {:ok, nil}
      end
    end)
    |> Ecto.Multi.run(:support, fn _repo, _changes ->
      {:ok, message} =
        result =
        T.Support.add_message(from_user_id, T.Support.admin_id(), %{
          "kind" => "text",
          "data" => %{
            "text" =>
              dgettext(
                "report",
                "Расскажи, что произошло и мы постараемся помочь. Будем стараться, чтобы подобный опыт не повторился в будущем!"
              )
          }
        })

      # TODO no web here
      TWeb.Endpoint.broadcast!(
        "support:#{from_user_id}",
        "message:new",
        %{message: TWeb.MessageView.render("show.json", %{message: message})}
      )

      result
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _changes} -> :ok
      {:error, :report, %Ecto.Changeset{} = changeset, _changes} -> {:error, changeset}
    end
  end

  # TODO test, unmatch
  defp maybe_block_user_multi(multi, reported_user_id) do
    Ecto.Multi.run(multi, :block, fn repo, _changes ->
      reports_count =
        UserReport |> where(on_user_id: ^reported_user_id) |> select([r], count()) |> Repo.one!()

      blocked? =
        if reports_count >= 3 do
          reported_user_id
          |> block_user_q()
          |> repo.update_all([])

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

  # TODO test unmatch doesn't unhide blocked
  def block_user(user_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:block, fn repo, _changes ->
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

  def delete_user(user_id) do
    Ecto.Multi.new()
    |> unmatch_all(user_id)
    |> Ecto.Multi.run(:session_tokens, fn _repo, _changes ->
      tokens = UserToken |> where(user_id: ^user_id) |> select([ut], ut.token) |> Repo.all()
      {:ok, tokens}
    end)
    |> Ecto.Multi.run(:delete_user, fn _repo, _changes ->
      {1, _} =
        User
        |> where(id: ^user_id)
        |> Repo.delete_all()

      {:ok, true}
    end)
    |> Repo.transaction()
  end

  # TODO test
  defp unmatch_all(multi, user_id) do
    Ecto.Multi.run(multi, :unmatch, fn repo, _changes ->
      unmatches =
        T.Matches.Match
        |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
        |> select([m], m.id)
        |> repo.all()
        |> Enum.map(fn match_id ->
          T.Matches.unmatch(user: user_id, match: match_id)
        end)

      {:ok, unmatches}
    end)
  end

  def save_apns_device_id(user_id, token, device_id) do
    %UserToken{id: token_id} = token |> UserToken.token_and_context_query("mobile") |> Repo.one!()

    prev_device_q =
      APNSDevice
      |> where([d], d.user_id == ^user_id and d.token_id == ^token_id)
      |> or_where(device_id: ^device_id)

    Repo.transaction(fn ->
      Repo.delete_all(prev_device_q)
      Repo.insert!(%APNSDevice{user_id: user_id, token_id: token_id, device_id: device_id})
    end)

    :ok
  end

  @doc "remove_apns_device(device_id_base_16)"
  def remove_apns_device(device_id) do
    APNSDevice
    |> where(device_id: ^Base.decode16!(device_id))
    |> Repo.delete_all()
  end

  def save_pushkit_device_id(user_id, token, device_id) do
    %UserToken{id: token_id} = token |> UserToken.token_and_context_query("mobile") |> Repo.one!()

    prev_device_q =
      PushKitDevice
      |> where([d], d.user_id == ^user_id and d.token_id == ^token_id)
      |> or_where(device_id: ^device_id)

    Repo.transaction(fn ->
      Repo.delete_all(prev_device_q)
      Repo.insert!(%PushKitDevice{user_id: user_id, token_id: token_id, device_id: device_id})
    end)

    :ok
  end

  @doc "remove_pushkit_device(device_id_base_16)"
  def remove_pushkit_device(device_id) do
    PushKitDevice
    |> where(device_id: ^Base.decode16!(device_id))
    |> Repo.delete_all()
  end

  def list_pushkit_devices(user_id) when is_binary(user_id) do
    PushKitDevice
    |> where(user_id: ^user_id)
    |> select([d], d.device_id)
    |> Repo.all()
    |> Enum.map(&Base.encode16/1)
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

  def save_photo(%User{id: user_id}, s3_key) do
    Profile
    |> where(user_id: ^user_id)
    |> select([p], p.photos)
    |> Repo.update_all(push: [photos: s3_key])
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
    Ecto.Multi.new()
    |> Ecto.Multi.run(:user, fn repo, _changes ->
      user = repo.get!(User, user_id)

      if user.onboarded_at do
        {:error, :already_onboarded}
      else
        {:ok, repo.preload(user, :profile)}
      end
    end)
    |> Ecto.Multi.update(:profile, fn %{user: %{profile: profile}} ->
      Profile.changeset(profile, attrs, validate_required?: true)
    end)
    |> update_profile_gender_preferences(profile)
    |> Ecto.Multi.run(:mark_onboarded, fn repo, %{user: user} ->
      {1, nil} =
        User
        |> where(id: ^user.id)
        |> update([u], set: [onboarded_at: fragment("now()")])
        |> repo.update_all([])

      {:ok, nil}
    end)
    |> Ecto.Multi.run(:show_profile, fn _repo, %{user: user} ->
      {count, nil} = maybe_unhide_profile_with_story(user.id)
      {:ok, count >= 1}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user, profile: %Profile{} = profile}} ->
        T.Bot.post_user_onboarded(user.phone_number)
        {:ok, %Profile{profile | hidden?: false}}

      {:error, :user, :already_onboarded, _changes} ->
        {:error, :already_onboarded}

      {:error, :profile, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end

    # |> notify_subscribers([:user, :new])
  end

  def update_profile(%Profile{} = profile, attrs, opts \\ []) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:profile, Profile.changeset(profile, attrs, opts), returning: true)
    |> update_profile_gender_preferences(profile)
    |> Ecto.Multi.run(:maybe_unhide, fn _repo, %{profile: profile} ->
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
    Ecto.Multi.run(multi, :update_profile_gender_preferences, fn _repo, %{profile: new_profile} ->
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
    Ecto.Multi.run(multi, :update_profile_gender_preferences, fn _repo, %{profile: new_profile} ->
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
            "size" => [189.07328717534452, 112.30428159468043],
            "value" => "перелестни на\nследующую\nстраницу 👉👉",
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
end
