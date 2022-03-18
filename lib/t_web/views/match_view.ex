defmodule TWeb.MatchView do
  use TWeb, :view
  alias TWeb.FeedView
  alias T.Matches.{Timeslot, MatchContact, Interaction}

  def render("match.json", %{id: id} = assigns) do
    inserted_at = ensure_utc(assigns[:inserted_at])
    expiration_date = ensure_utc(assigns[:expiration_date])

    timeslot =
      case assigns[:timeslot] do
        %Timeslot{} = timeslot -> render_timeslot(timeslot)
        _not_loaded_or_nil -> nil
      end

    contact =
      case assigns[:contact] do
        %MatchContact{} = contact -> render_contact(contact)
        _not_loaded_or_nil -> nil
      end

    %{"id" => id, "profile" => render(FeedView, "feed_profile.json", assigns)}
    |> maybe_put("inserted_at", inserted_at)
    |> maybe_put("expiration_date", expiration_date)
    |> maybe_put("audio_only", assigns[:audio_only])
    |> maybe_put("last_interaction_id", assigns[:last_interaction_id])
    |> maybe_put_2("seen", assigns[:seen])
    |> maybe_put("timeslot", timeslot)
    |> maybe_put("contact", contact)
  end

  def render("interaction.json", %{interaction: interaction}) do
    %Interaction{data: %{"type" => type}} = interaction
    render_interaction(type, interaction)
  end

  defp render_interaction("slots_offer" = type, interaction) do
    %Interaction{id: id, from_user_id: offerer, data: %{"slots" => slots}} = interaction

    %{
      "id" => id,
      "type" => type,
      "slots" => slots,
      "inserted_at" => datetime(id),
      "by_user_id" => offerer
    }
  end

  defp render_interaction("slot_accept" = type, interaction) do
    %Interaction{id: id, from_user_id: picker, data: %{"slot" => slot}} = interaction

    %{
      "id" => id,
      "type" => type,
      "by_user_id" => picker,
      "selected_slot" => slot,
      "inserted_at" => datetime(id)
    }
  end

  defp render_interaction("slot_cancel" = type, interaction) do
    %Interaction{id: id, from_user_id: offerer} = interaction
    %{"id" => id, "type" => type, "by_user_id" => offerer, "inserted_at" => datetime(id)}
  end

  defp render_interaction("contact_offer" = type, interaction) do
    %Interaction{id: id, from_user_id: offerer, data: %{"contacts" => contacts}} = interaction

    %{
      "id" => id,
      "type" => type,
      "contacts" => contacts,
      "by_user_id" => offerer,
      "inserted_at" => datetime(id)
    }
  end

  defp render_timeslot(%Timeslot{
         selected_slot: nil,
         accepted_at: nil,
         picker_id: picker,
         slots: slots,
         inserted_at: inserted_at
       }) do
    %{
      "slots" => slots,
      "picker" => picker,
      "inserted_at" => DateTime.from_naive!(inserted_at, "Etc/UTC")
    }
  end

  defp render_timeslot(%Timeslot{
         selected_slot: selected_slot,
         accepted_at: accepted_at,
         inserted_at: inserted_at
       }) do
    %{
      "selected_slot" => selected_slot,
      "accepted_at" => accepted_at,
      "inserted_at" => DateTime.from_naive!(inserted_at, "Etc/UTC")
    }
  end

  defp render_contact(%MatchContact{
         contacts: contacts,
         picker_id: picker,
         opened_contact_type: opened_contact_type,
         inserted_at: inserted_at,
         seen_at: seen_at
       }) do
    contact = %{
      "contacts" => contacts,
      "picker" => picker,
      "opened_contact_type" => opened_contact_type,
      "inserted_at" => DateTime.from_naive!(inserted_at, "Etc/UTC")
    }

    maybe_put(contact, "seen_at", seen_at)
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp maybe_put_2(map, _k, nil), do: map
  defp maybe_put_2(map, _k, false), do: map
  defp maybe_put_2(map, k, v), do: Map.put(map, k, v)

  defp datetime(<<_::288>> = uuid) do
    datetime(Ecto.Bigflake.UUID.dump!(uuid))
  end

  defp datetime(<<unix::64, _rest::64>>) do
    unix |> DateTime.from_unix!(:millisecond) |> DateTime.truncate(:second)
  end

  defp ensure_utc(%DateTime{} = datetime), do: datetime
  defp ensure_utc(%NaiveDateTime{} = naive), do: DateTime.from_naive!(naive, "Etc/UTC")
  defp ensure_utc(nil), do: nil
end
