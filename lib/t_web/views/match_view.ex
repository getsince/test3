defmodule TWeb.MatchView do
  use TWeb, :view
  alias TWeb.FeedView
  alias T.Matches.{Timeslot, MatchContact, Interaction}
  alias T.Calls
  alias T.Calls.Voicemail

  def render("match.json", %{id: id} = assigns) do
    inserted_at =
      if naive = assigns[:inserted_at] do
        DateTime.from_naive!(naive, "Etc/UTC")
      end

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

    voicemail =
      case assigns[:voicemail] do
        [%Voicemail{} | _rest] = voicemail -> render_voicemail(voicemail)
        _not_loaded_or_empty -> nil
      end

    %{"id" => id, "profile" => render(FeedView, "feed_profile.json", assigns)}
    |> maybe_put("inserted_at", inserted_at)
    |> maybe_put("audio_only", assigns[:audio_only])
    |> maybe_put("expiration_date", assigns[:expiration_date])
    |> maybe_put("timeslot", timeslot)
    |> maybe_put("contact", contact)
    |> maybe_put("voicemail", voicemail)
  end

  def render("interaction.json", %{interaction: interaction}) do
    %Interaction{data: %{"type" => type}} = interaction
    render_interaction(type, interaction)
  end

  defp render_interaction("slots_offer" = type, interaction) do
    %Interaction{id: id, to_user_id: picker, data: %{"slots" => slots}} = interaction

    %{
      "id" => id,
      "type" => type,
      "slots" => slots,
      "inserted_at" => datetime(id),
      "picker" => picker
    }
  end

  defp render_interaction("slot_accept" = type, interaction) do
    %Interaction{id: id, data: %{"slot" => slot}} = interaction
    %{"id" => id, "type" => type, "selected_slot" => slot, "accepted_at" => datetime(id)}
  end

  defp render_interaction("slot_cancel" = type, interaction) do
    %Interaction{id: id, from_user_id: by_user_id} = interaction
    %{"id" => id, "type" => type, "by_user_id" => by_user_id, "cancelled_at" => datetime(id)}
  end

  defp render_interaction("contact_offer" = type, interaction) do
    %Interaction{id: id, data: %{"contacts" => contacts}, to_user_id: picker} = interaction

    %{
      "id" => id,
      "type" => type,
      "contacts" => contacts,
      "picker" => picker,
      "inserted_at" => datetime(id)
    }
  end

  defp render_interaction("contact_cancel" = type, interaction) do
    %Interaction{id: id, data: _data, from_user_id: by_user_id} = interaction
    %{"id" => id, "type" => type, "by" => by_user_id, "at" => datetime(id)}
    # |> maybe_put("cancels", data["id"])
  end

  defp render_interaction("voicemail" = type, interaction) do
    %Interaction{id: id, from_user_id: caller, data: %{"s3" => s3_key}} = interaction

    %{
      "id" => id,
      "type" => type,
      "caller" => caller,
      "s3_key" => s3_key,
      "url" => Calls.voicemail_url(s3_key),
      "inserted_at" => datetime(id)
    }
  end

  defp render_interaction("call_attempt" = type, interaction) do
    %Interaction{id: id, from_user_id: caller} = interaction
    %{"id" => id, "type" => type, "caller" => caller, "attempted_at" => datetime(id)}
  end

  defp render_interaction("call_accepted", interaction) do
    %Interaction{id: id, data: %{"call_id" => call_id}} = interaction
    %{"id" => id, "type" => "call", "call_id" => call_id, "accepted_at" => datetime(id)}
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

  defp render_voicemail(voicemail) do
    grouped =
      voicemail
      |> Enum.sort_by(& &1.id)
      |> Enum.group_by(& &1.caller_id, fn voicemail ->
        %Voicemail{id: id, inserted_at: inserted_at, s3_key: s3_key, listened_at: listened_at} =
          voicemail

        rendered = %{
          id: id,
          inserted_at: DateTime.from_naive!(inserted_at, "Etc/UTC"),
          s3_key: s3_key,
          url: Calls.voicemail_url(s3_key)
        }

        maybe_put(rendered, :listened_at, listened_at)
      end)

    [caller_id] = Map.keys(grouped)
    [messages] = Map.values(grouped)

    %{"caller_id" => caller_id, "messages" => messages}
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp datetime(<<_::288>> = uuid) do
    datetime(Ecto.Bigflake.UUID.dump!(uuid))
  end

  defp datetime(<<unix::64, _rest::64>>) do
    unix |> DateTime.from_unix!(:millisecond) |> DateTime.truncate(:second)
  end
end
