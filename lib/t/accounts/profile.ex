defmodule T.Accounts.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @foreign_key_type Ecto.Bigflake.UUID
  schema "profiles" do
    belongs_to :user, T.Accounts.User, primary_key: true

    field :story, {:array, :map}
    field :location, Geo.PostGIS.Geometry

    # filters
    field :gender_preference, {:array, :map}, virtual: true
    field :min_age, :integer, virtual: true
    field :max_age, :integer, virtual: true
    field :distance, :integer, virtual: true

    # TODO move to users
    field :last_active, :utc_datetime

    # matched? not yet onboarded? deleted!? BLOCKED?
    field :hidden?, :boolean

    # general info
    field :name, :string
    field :gender, :string
    field :birthdate, :date
  end

  defp maybe_validate_required(changeset, opts, fun) when is_function(fun, 1) do
    if opts[:validate_required?], do: fun.(changeset), else: changeset
  end

  @known_genders ["M", "F", "N"]

  def essential_info_changeset(profile, attrs, opts \\ []) do
    attrs = attrs |> prepare_location()

    profile
    |> cast(attrs, [:name, :gender, :location, :birthdate])
    |> maybe_validate_required(opts, fn changeset ->
      validate_required(changeset, [:name, :gender, :location, :birthdate])
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

    # TODO
  end

  def changeset(profile, attrs, opts \\ []) do
    profile
    |> essential_info_changeset(attrs, opts)
    |> story_changeset(attrs)
  end
end
