defmodule T.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias T.{Repo, Media}

  alias T.Accounts.{
    User,
    Profile,
    UserToken,
    UserNotifier,
    UserReport,
    UserDeletionJob,
    APNSDevice
  }

  alias T.Feeds.PersonalityOverlapJob

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
  defp get_or_register_user(phone_number) do
    if u = get_user_by_phone_number(phone_number) do
      if u.deleted_at do
        {:error, :user_deleted}
      else
        {:ok, u}
      end
    else
      register_user(%{phone_number: phone_number})
    end
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
        |> where(alive?: true)
        |> where(user_id_1: ^u1)
        |> where(user_id_2: ^u2)
        |> select([m], m.id)
        |> repo.one()

      if match_id do
        T.Matches.unmatch(from_user_id, match_id)
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
              "Расскажи, что произошло и мы постараемся помочь. Будем стараться, чтобы подобный опыт не повторился в будущем!"
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

  # TODO test
  # TODO unmatch
  def block_user(user_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:block, fn repo, _changes ->
      user_id |> block_user_q() |> repo.update_all([])

      Profile
      |> where(user_id: ^user_id)
      |> repo.update_all(set: [hidden?: true])

      {:ok, nil}
    end)
    |> Ecto.Multi.run(:unmatch, fn repo, _changes ->
      match_id =
        T.Matches.Match
        |> where(alive?: true)
        |> where([m], m.user_id_1 == ^user_id or m.user_id_2 == ^user_id)
        |> select([m], m.id)
        |> repo.one()

      if match_id do
        T.Matches.unmatch(user_id, match_id)
      else
        {:ok, nil}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _changes} -> :ok
    end
  end

  defp hide_profile(repo, user_id) do
    Profile
    |> where(user_id: ^user_id)
    |> repo.update_all(set: [hidden?: true])
  end

  defp delete_user_q(user_id) do
    rand = to_string(:rand.uniform(1_000_000))

    User
    |> where(id: ^user_id)
    |> update([u],
      set: [
        deleted_at: fragment("now()"),
        phone_number: fragment("? || '-DELETED-' || ?", u.phone_number, ^rand)
      ]
    )
  end

  @two_days_in_seconds 2 * 24 * 60 * 60

  def delete_user(user_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:delete_user, fn repo, _changes ->
      {1, nil} = repo.update_all(delete_user_q(user_id), [])
      {:ok, nil}
    end)
    |> Ecto.Multi.run(:hide_profile, fn repo, _changes ->
      hide_profile(repo, user_id)
      {:ok, nil}
    end)
    |> Ecto.Multi.run(:delete_sessions, fn repo, _changes ->
      {_, tokens} =
        UserToken
        |> where(user_id: ^user_id)
        |> select([t], t.token)
        |> repo.delete_all()

      # for token <- tokens do
      #   encoded_token = UserToken.encoded_token(token)
      #   # TODO no web in here
      #   TWeb.Endpoint.broadcast("user_socket:#{encoded_token}", "disconnect", %{})
      # end

      {:ok, tokens}
    end)
    |> Ecto.Multi.run(:unmatch, fn repo, _changes ->
      match_id =
        T.Matches.Match
        |> where([m], m.user_id_1 == ^user_id or m.user_id_1 == ^user_id)
        |> where(alive?: true)
        |> select([m], m.id)
        |> repo.one()

      if match_id do
        T.Matches.unmatch(user_id, match_id)
      end

      {:ok, nil}
    end)
    |> Oban.insert(:deletion_job, fn _ ->
      UserDeletionJob.new(%{"user_id" => user_id}, schedule_in: @two_days_in_seconds)
    end)
    |> Repo.transaction()
  end

  def save_apns_device_id(user_id, token, device_id) do
    %UserToken{id: token_id} = token |> UserToken.token_and_context_query("mobile") |> Repo.one!()

    # duplicate device_id conflict target?
    # TODO ensure tokens are deleted on logout
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
    Media.s3_url()
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
      {:ok, %{profile: %Profile{} = profile}} -> {:ok, %Profile{profile | hidden?: false}}
      {:error, :user, :already_onboarded, _changes} -> {:error, :already_onboarded}
      {:error, :profile, %Ecto.Changeset{} = changeset, _changes} -> {:error, changeset}
    end

    # |> notify_subscribers([:user, :new])
  end

  def update_profile(%Profile{} = profile, attrs, opts \\ []) do
    profile
    |> Profile.changeset(attrs, opts)
    |> Repo.update(returning: true)
  end

  # TODO
  def update_profile_photo_at_position(user_id, s3_key, position) when position in [1, 2, 3, 4] do
    sql = "update profiles set photos[$1] = $2 where user_id = $3"

    %Postgrex.Result{num_rows: 1} =
      Repo.query!(sql, [position, s3_key, Ecto.Bigflake.UUID.dump!(user_id)])

    :ok
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
