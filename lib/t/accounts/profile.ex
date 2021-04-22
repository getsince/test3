defmodule T.Accounts.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "profiles" do
    belongs_to :user, T.Accounts.User, primary_key: true

    field :story, {:array, :map}

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

  defp maybe_validate_required(changeset, opts, fun) when is_function(fun, 1) do
    if opts[:validate_required?], do: fun.(changeset), else: changeset
  end

  def song_changeset(profile, attrs) do
    profile
    |> cast(attrs, [:song])
  end

  def essential_info_changeset(profile, attrs, opts \\ []) do
    profile
    |> cast(attrs, [:name, :gender])
    |> maybe_validate_required(opts, fn changeset ->
      validate_required(changeset, [:name, :gender])
    end)
    |> validate_inclusion(:gender, ["M", "F"])
    |> validate_length(:name, max: 100)
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

  @known_tastes @tastes ++ Enum.map(@tastes, &to_string/1)

  defp filter_tastes(tastes) do
    tastes
    |> Enum.filter(fn {k, _} -> k in @known_tastes end)
    |> Map.new(fn {k, v} -> {k, filter_taste_values(to_string(k), v)} end)
  end

  defp filter_taste_values("alcohol", v), do: v
  defp filter_taste_values("smoking", v), do: v
  defp filter_taste_values(_k, v), do: Enum.filter(v, &is_binary/1)

  def tastes_changeset(profile, attrs) do
    profile
    |> cast(attrs, [:tastes])
    |> update_change(:tastes, &filter_tastes/1)
  end

  def story_changeset(profile, attrs) do
    profile
    |> cast(attrs, [:story])

    # TODO
  end

  def changeset(profile, attrs, opts \\ []) do
    profile
    |> essential_info_changeset(attrs, opts)
    |> song_changeset(attrs)
    |> story_changeset(attrs)
  end
end
