defmodule T.Accounts.User.Profile do
  use Ecto.Schema
  import TWeb.Gettext
  import Ecto.Changeset

  @primary_key false
  @foreign_key_type Ecto.UUID
  schema "profiles" do
    belongs_to :user, T.Accounts.User, primary_key: true

    field :photos, {:array, :string}

    # general info
    field :name, :string
    field :gender, :string
    field :birthdate, :date
    field :height, :integer
    field :home_city, :string

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
    field :music, {:array, :string}
    field :sports, {:array, :string}
    field :alcohol, :string
    field :smoking, :string
    field :books, {:array, :string}
    field :currently_studying, {:array, :string}
    field :tv_shows, {:array, :string}
    field :languages, {:array, :string}
    field :musical_instruments, {:array, :string}
    field :movies, {:array, :string}
    field :social_networks, {:array, :string}
    field :cuisines, {:array, :string}
    field :pets, {:array, :string}
  end

  defp force_field_changes(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, changeset ->
      force_change(changeset, field, get_field(changeset, field))
    end)
  end

  def photos_changeset(profile, attrs, opts) do
    validate? = Keyword.fetch!(opts, :validate?)

    changeset =
      profile
      |> cast(attrs, [:photos])
      |> validate_required([:photos])

    if validate? do
      changeset
      |> force_field_changes([:photos])
      |> validate_length(:photos, min: 3, max: 6)
    else
      changeset
    end
  end

  def general_info_changeset(profile, attrs) do
    attrs = prepare_birthdate(attrs)

    profile
    |> cast(attrs, [:name, :birthdate, :gender, :height, :home_city])
    |> validate_required([:name, :birthdate, :gender, :height, :home_city])
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

  # TODO
  defp prepare_birthdate(%{"birthdate" => birthdate} = attrs) do
    Map.put(attrs, "birthdate", prepare_birthdate(birthdate))
  end

  defp prepare_birthdate(%{birthdate: birthdate} = attrs) do
    Map.put(attrs, :birthdate, prepare_birthdate(birthdate))
  end

  defp prepare_birthdate(birthdate) when is_binary(birthdate) do
    # TODO don't fail
    case Timex.parse(birthdate, "{D}/{M}/{YYYY}") do
      {:ok, date} -> date
      {:error, _reason} -> birthdate
    end
  end

  defp prepare_birthdate(attrs), do: attrs

  def work_and_education_changeset(profile, attrs) do
    profile
    |> cast(attrs, [:occupation, :job, :university, :major])
    |> validate_length(:occupation, max: 100)
    |> validate_length(:job, max: 100)
    |> validate_length(:university, max: 100)
    |> validate_length(:major, max: 100)
  end

  def about_self_changeset(profile, attrs) do
    profile
    |> cast(attrs, [:most_important_in_life, :interests, :first_date_idea, :free_form])
    |> validate_required([:most_important_in_life, :interests, :first_date_idea])
    |> force_field_changes([:interests])
    |> validate_length(:interests, min: 2, max: 5)
    |> validate_length(:most_important_in_life, max: 100)
    |> validate_length(:first_date_idea, max: 100)
    |> validate_length(:free_form, max: 1000)
  end

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

  def tastes_changeset(profile, attrs) do
    profile
    |> cast(attrs, @tastes)
    |> at_least_seven_tastes()
    |> validate_length(:alcohol, max: 100)
    |> validate_length(:smoking, max: 100)
    |> validate_length(:music, min: 1, max: 5)
    |> validate_length(:sports, min: 1, max: 5)
    |> validate_length(:books, min: 1, max: 5)
    |> validate_length(:currently_studying, min: 1, max: 5)
    |> validate_length(:tv_shows, min: 1, max: 5)
    |> validate_length(:languages, min: 1, max: 5)
    |> validate_length(:musical_instruments, min: 1, max: 5)
    |> validate_length(:movies, min: 1, max: 5)
    |> validate_length(:social_networks, min: 1, max: 5)
    |> validate_length(:cuisines, min: 1, max: 5)
    |> validate_length(:pets, min: 1, max: 5)
  end

  defp at_least_seven_tastes(changeset) do
    provided_tastes =
      @tastes
      |> Enum.map(&get_field(changeset, &1))
      |> Enum.reject(fn
        nil -> true
        [] -> true
        _other -> false
      end)

    if length(provided_tastes) < 7 do
      add_error(changeset, :tastes, dgettext("errors", "should have at least 7 tastes"))
    else
      changeset
    end
  end

  def final_changeset(profile, attrs) do
    profile
    |> photos_changeset(attrs, validate?: true)
    |> general_info_changeset(attrs)
    |> work_and_education_changeset(attrs)
    |> about_self_changeset(attrs)
    |> tastes_changeset(attrs)
  end
end
