defmodule T.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias T.Repo
  alias T.Accounts.{User, UserToken, UserNotifier}

  ## Database getters

  @doc """
  Gets a user by phone number.

  ## Examples

      iex> get_user_by_phone_number("+79161231234")
      %User{}

      iex> get_user_by_phone_number("+11111111111")
      nil

  """
  def get_user_by_phone_number(phone_number) when is_binary(phone_number) do
    Repo.get_by(User, phone_number: phone_number)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user and their profile.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:user, User.registration_changeset(%User{}, attrs))
    |> Ecto.Multi.insert(:profile, fn %{user: user} -> %User.Profile{user_id: user.id} end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, %Ecto.Changeset{} = changeset, _changes} -> {:error, changeset}
    end
  end

  def get_or_register_user(phone_number) do
    if u = get_user_by_phone_number(phone_number) do
      {:ok, u}
    else
      register_user(%{phone_number: phone_number})
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
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

  @doc """
  Confirms a user by the given code.

  If the code matches, the user account is marked as confirmed.
  """
  def login_or_register_user(phone_number, code) do
    # TODO normalize phone number
    with :ok <- PasswordlessAuth.verify_code(phone_number, code),
         {:ok, user} <- get_or_register_user(phone_number) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  def save_photo(%User{id: user_id}, s3_key) do
    User.Profile
    |> where(user_id: ^user_id)
    |> update([p], push: [photos: ^s3_key])
    |> select([p], p.photos)
    |> Repo.update_all([])
  end

  # TODO do this when creating user account
  def ensure_profile(%User{id: user_id} = user) do
    profile = Repo.get(User.Profile, user_id) || Repo.insert!(%User.Profile{user_id: user_id})
    %User{user | profile: profile}
  end

  def update_photos(profile, attrs, opts) do
    profile
    |> User.Profile.photos_changeset(attrs, opts)
    |> Repo.update()
  end

  def update_general_profile_info(profile, attrs) do
    profile
    |> User.Profile.general_info_changeset(attrs)
    |> Repo.update()
  end

  def update_work_and_education_info(profile, attrs) do
    profile
    |> User.Profile.work_and_education_changeset(attrs)
    |> Repo.update()
  end

  def update_about_self_info(profile, attrs) do
    profile
    |> User.Profile.about_self_changeset(attrs)
    |> Repo.update()
  end

  def update_tastes(profile, attrs) do
    profile
    |> User.Profile.tastes_changeset(attrs)
    |> Repo.update()
  end

  def finish_onboarding(user_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:user, fn _repo, _changes ->
      user = User |> Repo.get!(user_id) |> Repo.preload(:profile)

      if user.onboarded_at do
        {:error, :already_onboarded}
      else
        {:ok, user}
      end
    end)
    |> Ecto.Multi.run(:profile_check, fn _repo, %{user: %{profile: profile}} ->
      changeset = User.Profile.final_changeset(profile, %{})

      if changeset.valid? do
        {:ok, nil}
      else
        {:error, changeset}
      end
    end)
    |> Ecto.Multi.run(:mark_onboarded, fn _repo, %{user: user} ->
      {1, nil} =
        User
        |> where(id: ^user.id)
        |> update([u], set: [onboarded_at: fragment("now()")])
        |> Repo.update_all([])

      {:ok, nil}
    end)
    |> Ecto.Multi.run(:load_user, fn _repo, %{user: user} ->
      {:ok, User |> Repo.get!(user.id) |> Repo.preload(:profile)}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{load_user: %User{} = user}} -> {:ok, user}
      {:error, :user, :already_onboarded, _changes} -> {:error, :already_onboarded}
      {:error, :profile_check, %Ecto.Changeset{} = changeset, _changes} -> {:error, changeset}
    end
  end
end
