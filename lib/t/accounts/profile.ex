defmodule T.Accounts.Profile do
  use Ecto.Schema
  import Ecto.Changeset
  alias T.Stickers

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "profiles" do
    belongs_to :user, T.Accounts.User, primary_key: true

    field :story, {:array, :map}
    field :location, Geo.PostGIS.Geometry

    # filters
    field :gender_preference, {:array, :string}, virtual: true
    field :min_age, :integer
    field :max_age, :integer
    field :distance, :integer

    # TODO move to users
    field :last_active, :utc_datetime

    # matched? not yet onboarded? deleted!? BLOCKED?
    field :hidden?, :boolean

    # general info
    field :name, :string
    field :gender, :string
    field :birthdate, :date

    # settings
    field :audio_only, :boolean, virtual: true
  end

  defp maybe_validate_required(changeset, opts, fun) when is_function(fun, 1) do
    if opts[:validate_required?], do: fun.(changeset), else: changeset
  end

  @known_genders ["M", "F", "N"]

  def essential_info_changeset(profile, attrs, opts \\ []) do
    attrs = attrs |> prepare_location()

    profile
    |> cast(attrs, [
      :name,
      :gender,
      :location,
      :birthdate,
      :min_age,
      :max_age,
      :distance,
      :gender_preference
    ])
    |> maybe_validate_required(opts, fn changeset ->
      validate_required(changeset, [:name, :gender, :location, :birthdate, :gender_preference])
    end)
    |> validate_inclusion(:gender, @known_genders)
    |> validate_length(:name, max: 100)
    |> validate_change(:birthdate, fn :birthdate, birthdate ->
      %{year: y, month: m, day: d} = DateTime.utc_now()
      young = %Date{year: y - 18, month: m, day: d}
      old = %Date{year: y - 100, month: m, day: d}

      young_comp = Date.compare(young, birthdate)
      old_comp = Date.compare(old, birthdate)

      case {young_comp, old_comp} do
        {:lt, _} -> [birthdate: "too young"]
        {_, :gt} -> [birthdate: "too old"]
        _ -> []
      end
    end)
    |> validate_subset(:gender_preference, @known_genders)
  end

  defp prepare_location(%{"latitude" => lat, "longitude" => lon} = attrs) do
    Map.put(attrs, "location", point(lat, lon))
  end

  defp prepare_location(%{latitude: lat, longitude: lon} = attrs) do
    Map.put(attrs, :location, point(lat, lon))
  end

  defp prepare_location(attrs), do: attrs

  defp point(lat, lon) do
    %Geo.Point{coordinates: {lon, lat}, srid: 4326}
  end

  def story_changeset(profile, attrs) do
    profile
    |> cast(attrs, [:story])
    |> update_change(:story, fn story -> Stickers.fix_story(story) end)
  end

  def changeset(profile, attrs, opts \\ []) do
    profile
    |> essential_info_changeset(attrs, opts)
    |> story_changeset(attrs)
  end
end
