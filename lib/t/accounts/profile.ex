defmodule T.Accounts.Profile do
  use Ecto.Schema
  import Ecto.Changeset
  import T.Gettext
  alias T.Stickers
  alias T.StoryBackground

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
  end

  def changeset(profile, attrs, opts \\ []) do
    profile
    |> essential_info_changeset(attrs, opts)
    |> story_changeset(attrs)
  end

  defp maybe_validate_required(changeset, opts, fun) when is_function(fun, 1) do
    if opts[:validate_required?], do: fun.(changeset), else: changeset
  end

  @known_genders ["M", "F", "N"]
  @contacts [
    "telegram",
    "instagram",
    "whatsapp",
    "phone",
    "email",
    "imessage",
    "snapchat",
    "messenger",
    "signal",
    "twitter"
  ]

  def contacts, do: @contacts

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
    |> update_change(:story, fn story ->
      story |> Stickers.fix_story() |> StoryBackground.fix_story()
    end)
    |> validate_story()
  end

  defp validate_story(%Ecto.Changeset{changes: %{story: story}} = cs) do
    case validate_story(story || [], _validated = [], _errors = []) do
      {:ok, story} ->
        force_change(cs, :story, story)

      {:error, errors} when is_list(errors) ->
        Enum.reduce(errors, cs, fn {error, opts}, cs ->
          add_error(cs, :story, error, opts)
        end)
    end
  end

  defp validate_story(changeset), do: changeset

  @spec validate_story([map], [map], [Ecto.Changeset.error()]) ::
          {:ok, [map]} | {:error, [Ecto.Changeset.error()]}
  defp validate_story([page | pages], validated_story, errors) do
    {page, new_errors} = validate_page(page)
    validate_story(pages, [page | validated_story], new_errors ++ errors)
  end

  defp validate_story([], validated, _no_errors = []), do: {:ok, :lists.reverse(validated)}
  defp validate_story([], _validated_story, errors), do: {:error, errors}

  @spec validate_page(map) :: {map, [Ecto.Changeset.error()]}
  defp validate_page(%{"labels" => labels} = page) do
    {labels, errors} = validate_labels(labels || [], _validated = [], _errors = [])
    {%{page | "labels" => labels}, errors}
  end

  defp validate_page(page), do: {page, _no_labels_no_errors = []}

  @spec validate_labels([map], [map], [Ecto.Changeset.error()]) ::
          {[map], [Ecto.Changeset.error()]}
  defp validate_labels([label | labels], validated, errors) do
    case label do
      %{"question" => q} when q in @contacts ->
        case validate_contact(q, label) do
          %Ecto.Changeset{valid?: true} = cs ->
            %{answer: answer} = apply_changes(cs)
            label = label |> Map.put("answer", answer) |> Map.delete("value")
            validate_labels(labels, [label | validated], errors)

          %Ecto.Changeset{valid?: false} = cs ->
            validate_labels(labels, validated, render_contact_errors(cs) ++ errors)
        end

      label ->
        validate_labels(labels, [label | validated], errors)
    end
  end

  defp validate_labels([], validated, errors), do: {:lists.reverse(validated), errors}

  @spec render_contact_errors(Ecto.Changeset.t()) :: [Ecto.Changeset.error()]
  defp render_contact_errors(changeset) do
    %{answer: answer} = traverse_errors(changeset, fn error -> error end)
    answer
  end

  @spec validate_contact(String.t(), map) :: Ecto.Changeset.t()
  defp validate_contact("telegram", label) do
    label_name = dgettext("errors", "telegram username")

    contact_label_changeset(label_name, label)
    |> update_change(:answer, &trim_handle/1)
    |> label_validate_length(:answer, label_name, min: 5, max: 32)
    # based on https://github.com/lorey/social-media-profiles-regexs#telegram
    |> label_validate_format(:answer, label_name, ~r/^[a-z0-9\_]*$/)
  end

  defp validate_contact("instagram", label) do
    label_name = dgettext("errors", "instagram username")

    contact_label_changeset(label_name, label)
    |> update_change(:answer, &trim_handle/1)
    |> label_validate_length(:answer, label_name, min: 2, max: 30)
    |> label_validate_format(
      :answer,
      label_name,
      # based on https://github.com/lorey/social-media-profiles-regexs#instagram
      ~r/^[A-Za-z0-9_](?:(?:[A-Za-z0-9_]|(?:\.(?!\.))){0,99}(?:[A-Za-z0-9_]))$/
    )
  end

  defp validate_contact("snapchat", label) do
    label_name = dgettext("errors", "snapchat username")

    contact_label_changeset(label_name, label)
    |> update_change(:answer, &trim_handle/1)
    |> label_validate_length(:answer, label_name, min: 3, max: 15)
    |> label_validate_format(
      :answer,
      label_name,
      # based on https://github.com/lorey/social-media-profiles-regexs#snapchat
      ~r/^[A-z0-9\.\_\-]+$/
    )
  end

  defp validate_contact("messenger", label) do
    label_name = dgettext("errors", "messenger username")

    contact_label_changeset(label_name, label)
    |> update_change(:answer, &trim_handle/1)
    |> label_validate_length(:answer, label_name, min: 5)
    |> label_validate_format(
      :answer,
      label_name,
      # based on https://github.com/lorey/social-media-profiles-regexs#facebook
      ~r/^[A-z0-9_\-\.]+$/
    )
  end

  defp validate_contact("twitter", label) do
    label_name = dgettext("errors", "twitter username")

    contact_label_changeset(label_name, label)
    |> update_change(:answer, &trim_handle/1)
    |> label_validate_length(:answer, label_name, min: 1, max: 15)
    |> label_validate_format(
      :answer,
      label_name,
      # based on https://github.com/lorey/social-media-profiles-regexs#twitter
      ~r/^[A-z0-9_]+$/
    )
  end

  # TODO use libphonenumber
  defp validate_contact("whatsapp", label) do
    label_name = dgettext("errors", "whatsapp phone number")

    contact_label_changeset(label_name, label)
    |> update_change(:answer, &trim_phone/1)
    |> label_validate_length(:answer, label_name, min: 4, max: 15)
    |> label_validate_format(:answer, label_name, ~r/^[0-9]*$/)
  end

  # TODO use libphonenumber
  defp validate_contact("signal", label) do
    label_name = dgettext("errors", "signal phone number")

    contact_label_changeset(label_name, label)
    |> update_change(:answer, &trim_phone/1)
    |> label_validate_length(:answer, label_name, min: 4, max: 15)
    |> label_validate_format(:answer, label_name, ~r/^[0-9]*$/)
    |> update_change(:answer, fn phone -> "+" <> phone end)
  end

  # TODO use libphonenumber
  defp validate_contact("imessage", label) do
    if String.contains?(label["answer"] || label["value"], "@") do
      label_name = dgettext("errors", "imessage email address")

      contact_label_changeset(label_name, label)
      |> update_change(:answer, fn address -> address |> String.downcase() |> String.trim() end)
      |> label_validate_format(
        :answer,
        label_name,
        Regex.compile!("^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$")
      )
      |> label_validate_length(:answer, label_name, min: 5, max: 60)
    else
      label_name = dgettext("errors", "imessage phone number")

      contact_label_changeset(label_name, label)
      |> update_change(:answer, &trim_phone/1)
      |> label_validate_length(:answer, label_name, min: 4, max: 15)
      |> label_validate_format(:answer, label_name, ~r/^[0-9]*$/)
      |> update_change(:answer, fn phone -> "+" <> phone end)
    end
  end

  # TODO use libphonenumber
  defp validate_contact("phone", label) do
    label_name = dgettext("errors", "phone number")

    contact_label_changeset(label_name, label)
    |> update_change(:answer, &trim_phone/1)
    |> label_validate_length(:answer, label_name, min: 4, max: 15)
    |> label_validate_format(:answer, label_name, ~r/^[0-9]*$/)
    |> update_change(:answer, fn phone -> "+" <> phone end)
  end

  defp validate_contact("email", label) do
    label_name = dgettext("errors", "email address")

    contact_label_changeset(label_name, label)
    |> update_change(:answer, fn address -> address |> String.downcase() |> String.trim() end)
    |> label_validate_format(
      :answer,
      label_name,
      Regex.compile!("^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$")
    )
    |> label_validate_length(:answer, label_name, min: 5, max: 60)
  end

  defp trim_handle(handle) do
    handle |> String.downcase() |> String.trim() |> String.trim_leading("@")
  end

  defp trim_phone(phone) do
    phone
    |> String.trim()
    |> String.replace(["(", ")", ".", "-", " ", "+"], "")
    |> String.trim_leading("0")
  end

  defp contact_label_changeset(label_name, label) do
    label = Map.put(label, "answer", label["answer"] || label["value"])

    {_data = %{}, _types = %{answer: :string}}
    |> cast(label, [:answer])
    |> label_validate_required([:answer], label_name)
  end

  @spec label_validate_format(Ecto.Changeset.t(), atom, String.t(), Regex.t()) ::
          Ecto.Changeset.t()
  defp label_validate_format(changeset, field, label_name, format) do
    validate_format(changeset, field, format,
      message: dgettext("errors", "%{label} has invalid format", label: label_name)
    )
  end

  @spec label_validate_length(Ecto.Changeset.t(), atom, String.t(), Keyword.t()) ::
          Ecto.Changeset.t()
  defp label_validate_length(changeset, field, label_name, opts) do
    changeset =
      if min = opts[:min] do
        validate_length(changeset, field,
          min: min,
          message:
            dgettext("errors", "%{label} should be at least %{count} character(s)",
              label: label_name,
              count: min
            )
        )
      end || changeset

    if max = opts[:max] do
      validate_length(changeset, field,
        max: max,
        message:
          dgettext("errors", "%{label} should be at most %{count} character(s)",
            label: label_name,
            count: max
          )
      )
    end || changeset
  end

  @spec label_validate_required(Ecto.Changeset.t(), list | atom, String.t()) :: Ecto.Changeset.t()
  defp label_validate_required(changeset, fields, label_name) do
    validate_required(changeset, fields,
      message: dgettext("errors", "%{label} can't be blank", label: label_name)
    )
  end
end
