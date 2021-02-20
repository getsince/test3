defmodule T.Accounts.Profile do
  use Ecto.Schema
  import TWeb.Gettext
  import Ecto.Changeset

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "profiles" do
    belongs_to :user, T.Accounts.User, primary_key: true

    field :photos, {:array, :string}
    field :times_liked, :integer

    # TODO move to users
    field :last_active, :utc_datetime

    # matched? not yet onboarded? deleted!? BLOCKED?
    field :hidden?, :boolean

    # general info
    field :name, :string
    field :gender, :string
    field :birthdate, :date
    field :height, :integer

    # audio
    field :song, :map

    # TODO replace with location?
    field :city, :string

    # work and education
    field :occupation, :string
    field :job, :string
    field :university, :string
    field :major, :string

    # about me
    field :most_important_in_life, :string
    field :interests, {:array, :string}
    field :first_date_idea, :string
    field :free_form, :string

    # tastes
    # field :tastes_list, {:array, :map}, virtual: true
    field :tastes, :map
    field :feed_reason, :string, virtual: true
  end

  defp force_field_changes(changeset, fields) when is_list(fields) do
    Enum.reduce(fields, changeset, fn field, changeset ->
      force_change(changeset, field, get_field(changeset, field))
    end)
  end

  defp maybe_validate_required(changeset, opts, fun) when is_function(fun, 1) do
    if opts[:validate_required?], do: fun.(changeset), else: changeset
  end

  def photos_changeset(profile, attrs, opts \\ []) do
    profile
    |> cast(attrs, [:photos])
    |> maybe_validate_required(opts, fn changeset ->
      changeset
      |> force_field_changes([:photos])
      |> validate_length(:photos, is: 4)
    end)
    |> validate_required([:photos])
  end

  def song_changeset(profile, attrs, opts \\ []) do
    profile
    |> cast(attrs, [:song])
    |> maybe_validate_required(opts, fn changeset ->
      changeset
      |> validate_required([:song])
    end)
  end

  def general_info_changeset(profile, attrs, opts \\ []) do
    profile
    |> cast(attrs, [:name, :birthdate, :gender, :height, :city])
    |> maybe_validate_required(opts, fn changeset ->
      validate_required(changeset, [:name, :birthdate, :gender, :height, :city])
    end)
    |> validate_inclusion(:gender, ["M", "F"])
    |> validate_number(:height, greater_than: 0, less_than_or_equal_to: 240)
    |> validate_length(:name, min: 3, max: 100)
    |> validate_change(:birthdate, fn :birthdate, date ->
      long_ago = ~D[1920-01-01]

      # TODO account for leap years or whatever
      too_young? = Date.diff(Date.utc_today(), date) < 365 * 16
      too_old? = Date.compare(long_ago, date) == :gt

      case {too_young?, too_old?} do
        {true, false} -> [birthdate: dgettext("errors", "too young")]
        {false, true} -> [birthdate: dgettext("errors", "too old")]
        {false, false} -> []
      end
    end)
  end

  def work_and_education_changeset(profile, attrs, opts \\ []) do
    profile
    |> cast(attrs, [:occupation, :job, :university, :major])
    |> maybe_validate_required(opts, fn changeset ->
      validate_required(changeset, [:occupation, :job])
    end)
    |> validate_length(:occupation, max: 100)
    |> validate_length(:job, max: 100)
    |> validate_length(:university, max: 200)
    |> validate_length(:major, max: 100)
  end

  def about_self_changeset(profile, attrs, opts \\ []) do
    profile
    |> cast(attrs, [:most_important_in_life, :interests, :first_date_idea, :free_form])
    |> maybe_validate_required(opts, fn changeset ->
      changeset
      |> validate_required([:most_important_in_life, :interests, :first_date_idea])
      |> force_field_changes([:interests])
    end)
    |> validate_length(:interests, min: 2, max: 5)
    |> validate_length(:most_important_in_life, max: 100)
    |> validate_length(:first_date_idea, max: 100)
    |> validate_length(:free_form, max: 1000)
  end

  # defmodule Tastes do
  #   use Ecto.Schema

  #   embedded_schema do
  #     field :music,
  #   end
  # end

  @tastes [
    :music,
    :sports,
    :alcohol,
    :smoking,
    :books,
    :currently_studying,
    :tv_shows,
    :languages,
    :musical_instruments,
    :movies,
    :social_networks,
    :cuisines,
    :pets
  ]

  @known_tastes @tastes ++ Enum.map(@tastes, &to_string/1)

  defp filter_tastes(tastes) do
    tastes
    |> Enum.filter(fn {k, _} -> k in @known_tastes end)
    |> Map.new(fn {k, v} -> {k, filter_taste_values(to_string(k), v)} end)
  end

  defp filter_taste_values("alcohol", v), do: v
  defp filter_taste_values("smoking", v), do: v
  defp filter_taste_values(_k, v), do: Enum.filter(v, &is_binary/1)

  def tastes_changeset(profile, attrs, opts \\ []) do
    profile
    |> cast(attrs, [:tastes])
    |> maybe_validate_required(opts, fn changeset ->
      changeset
      |> validate_required([:tastes])
      |> force_field_changes([:tastes])
    end)
    |> validate_change(:tastes, fn :tastes, tastes ->
      tastes = filter_tastes(tastes)

      if length(Map.keys(tastes)) >= 7 do
        []
      else
        [tastes: dgettext("errors", "should have at least 7 tastes")]
      end
    end)

    # |> maybe_validate_required(opts, &at_least_seven_tastes/1)
    # |> validate_length(:alcohol, max: 100)
    # |> validate_length(:smoking, max: 100)
    # |> validate_length(:music, min: 1, max: 5)
    # |> validate_length(:sports, min: 1, max: 5)
    # |> validate_length(:books, min: 1, max: 5)
    # |> validate_length(:currently_studying, min: 1, max: 5)
    # |> validate_length(:tv_shows, min: 1, max: 5)
    # |> validate_length(:languages, min: 1, max: 5)
    # |> validate_length(:musical_instruments, min: 1, max: 5)
    # |> validate_length(:movies, min: 1, max: 5)
    # |> validate_length(:social_networks, min: 1, max: 5)
    # |> validate_length(:cuisines, min: 1, max: 5)
    # |> validate_length(:pets, min: 1, max: 5)
  end

  # defp at_least_seven_tastes(changeset) do
  #   provided_tastes =
  #     @tastes
  #     |> Enum.map(&get_field(changeset, &1))
  #     |> Enum.reject(fn
  #       nil -> true
  #       [] -> true
  #       _other -> false
  #     end)

  #   if length(provided_tastes) < 7 do
  #     add_error(changeset, :tastes, dgettext("errors", "should have at least 7 tastes"))
  #   else
  #     changeset
  #   end
  # end

  def changeset(profile, attrs, opts \\ []) do
    profile
    |> photos_changeset(attrs, opts)
    |> song_changeset(attrs, opts)
    |> general_info_changeset(attrs, opts)
    |> work_and_education_changeset(attrs)
    |> about_self_changeset(attrs, opts)
    |> tastes_changeset(attrs, opts)
  end
end
