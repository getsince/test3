defmodule T.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias T.{Repo, Media}
  alias T.Accounts.{User, Profile, UserToken, UserNotifier, UserReport, APNSDevice}
  alias T.Feeds.PersonalityOverlapJob

  # def subscribe_to_new_users do
  #   Phoenix.PubSub.subscribe(T.PubSub, "new_users")
  # end

  # def notify_subscribers({:ok, %User{}}, [:new, :user]) do
  #   Phoenix.PubSub.broadcast()
  # end

  ## Database getters

  def get_user_by_phone_number(phone_number) when is_binary(phone_number) do
    Repo.get_by(User, phone_number: phone_number)
  end

  def get_user!(id), do: Repo.get!(User, id)

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
      {:ok, %{user: user, profile: profile}} -> {:ok, %User{user | profile: profile}}
      {:error, :user, %Ecto.Changeset{} = changeset, _changes} -> {:error, changeset}
    end
  end

  defp get_or_register_user(phone_number) do
    if u = get_user_by_phone_number(phone_number) do
      {:ok, u}
    else
      register_user(%{phone_number: phone_number})
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
    |> Repo.transaction()
    |> case do
      {:ok, _changes} -> :ok
      {:error, :report, %Ecto.Changeset{} = changeset, _changes} -> {:error, changeset}
    end
  end

  @doc false
  def maybe_block_user_multi(multi, reported_user_id) do
    Ecto.Multi.run(multi, :block, fn repo, _changes ->
      reports_count =
        UserReport |> where(on_user_id: ^reported_user_id) |> select([r], count()) |> Repo.one!()

      blocked? =
        if reports_count >= 3 do
          User
          |> where(id: ^reported_user_id)
          |> update([u], set: [blocked_at: fragment("now()")])
          |> repo.update_all([])

          Profile
          |> where(user_id: ^reported_user_id)
          |> repo.update_all(set: [hidden?: true])
        end

      {:ok, !!blocked?}
    end)
  end

  def save_apns_device_id(user_id, token, device_id) do
    %UserToken{id: token_id} = token |> UserToken.token_and_context_query("mobile") |> Repo.one!()

    Repo.insert!(%APNSDevice{user_id: user_id, token_id: token_id, device_id: device_id},
      on_conflict: {:replace, [:device_id, :updated_at]},
      conflict_target: [:user_id, :token_id]
    )

    :ok
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

  ## Confirmation

  @doc """
  Delivers the confirmation SMS instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(phone_number)
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_confirmation_instructions(phone_number) when is_binary(phone_number) do
    # TODO rate limit
    if valid_number?(phone_number) do
      code = PasswordlessAuth.generate_code(phone_number)
      UserNotifier.deliver_confirmation_instructions(phone_number, code)
    else
      {:error, :invalid_phone_number}
    end
  end

  def valid_number?(phone_number) do
    with {:ok, phone} <- ExPhoneNumber.parse(phone_number, "ru") do
      ExPhoneNumber.is_valid_number?(phone)
    else
      _ -> false
    end
  end

  def login_or_register_user(phone_number, code) do
    # TODO normalize phone number
    with {:phone, :ok} <- {:phone, PasswordlessAuth.verify_code(phone_number, code)},
         {:reg, {:ok, _user} = success} <- {:reg, get_or_register_user(phone_number)} do
      success
    else
      {:phone, error} -> error
      {:reg, error} -> error
    end
  end

  # TODO test
  def block_user(user_id) do
    Repo.transaction(fn ->
      User
      |> where(id: ^user_id)
      |> update([u], set: [blocked_at?: fragment("now()")])
      |> Repo.update_all([])

      hide_profile(user_id)
    end)

    :ok
  end

  defp hide_profile(user_id) do
    Profile
    |> where(user_id: ^user_id)
    |> Repo.update_all(set: [hidden?: true])
  end

  # TODO test
  def delete_user(user_id) do
    # TODO schedule for deletion
    Repo.transaction(fn ->
      User
      |> where(id: ^user_id)
      |> update([u], set: [deleted_at?: fragment("now()")])
      |> Repo.update_all([])

      hide_profile(user_id)
    end)

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
    Media.url()
  end

  def get_profile!(%User{id: user_id}) do
    get_profile!(user_id)
  end

  def get_profile!(user_id) when is_binary(user_id) do
    Repo.get!(Profile, user_id)
  end

  def onboard_profile(%Profile{user_id: user_id}, attrs) do
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
    |> Ecto.Multi.run(:mark_onboarded, fn repo, %{user: user} ->
      {1, nil} =
        User
        |> where(id: ^user.id)
        |> update([u], set: [onboarded_at: fragment("now()")])
        |> repo.update_all([])

      {:ok, nil}
    end)
    |> Ecto.Multi.run(:show_profile, fn repo, %{user: user} ->
      {1, nil} =
        Profile
        |> where(user_id: ^user.id)
        |> repo.update_all(set: [hidden?: false])

      {:ok, nil}
    end)
    |> Oban.insert(:schedule_overlap_job, PersonalityOverlapJob.new(%{"user_id" => user_id}))
    |> Repo.transaction()
    |> case do
      {:ok, %{profile: %Profile{} = profile}} -> {:ok, profile}
      {:error, :user, :already_onboarded, _changes} -> {:error, :already_onboarded}
      {:error, :profile, %Ecto.Changeset{} = changeset, _changes} -> {:error, changeset}
    end

    # |> notify_subscribers([:user, :new])
  end

  def update_profile(%Profile{} = profile, attrs, opts \\ []) do
    profile
    |> Profile.changeset(attrs, opts)
    |> Repo.update()
  end

  def validate_profile_photos(%Profile{} = profile) do
    profile
    |> Profile.photos_changeset(%{}, validate_required?: true)
    |> Repo.update()
  end

  def validate_profile_general_info(%Profile{} = profile) do
    profile
    |> Profile.general_info_changeset(%{}, validate_required?: true)
    |> Repo.update()
  end

  def validate_profile_work_and_education(%Profile{} = profile) do
    profile
    |> Profile.work_and_education_changeset(%{})
    |> Repo.update()
  end

  def validate_profile_about(%Profile{} = profile) do
    profile
    |> Profile.about_self_changeset(%{}, validate_required?: true)
    |> Repo.update()
  end

  def validate_profile_tastes(%Profile{} = profile) do
    profile
    |> Profile.tastes_changeset(%{}, validate_required?: true)
    |> Repo.update()
  end
end
