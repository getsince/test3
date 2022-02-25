defmodule Dev do
  def force_app_upgrade() do
    alert1_ru = %{
      "aps" => %{
        "alert" => %{
          "title" => "Ура, обновление! 🔥",
          "body" => "Новый режим — голосовая почта 🎤"
        }
      }
    }

    alert1_en = %{
      "aps" => %{
        "alert" => %{
          "title" => "Hurray, this is an update! 🔥",
          "body" => "Meet new mode: voicemail 🎤"
        }
      }
    }

    apns = T.Accounts.APNSDevice |> T.Repo.all()

    devices =
      Enum.map(apns, fn %{device_id: id} = device -> %{device | device_id: Base.encode16(id)} end)

    for device <- devices do
      %T.Accounts.APNSDevice{device_id: device_id, locale: locale, topic: topic, env: env} =
        device

      env =
        case env do
          "prod" -> :prod
          "sandbox" -> :dev
          nil -> :dev
        end

      case locale do
        "ru" ->
          APNS.build_notification(device_id, topic, alert1_ru, env) |> APNS.push(T.Finch)

        "en" ->
          APNS.build_notification(device_id, topic, alert1_en, env) |> APNS.push(T.Finch)

        _ ->
          APNS.build_notification(device_id, topic, alert1_ru, env) |> APNS.push(T.Finch)
      end
    end
  end

  @ig_contacts [
    %{ig: ["@durov"], user_id: "0000017c-0000-0000-0000-ac1100040000"}
  ]

  import Ecto.Query

  # use this function to get a list like above
  def ig_contacts do
    T.Matches.Interaction
    |> where([c], fragment("data ->> 'type'") == "contact_offer")
    |> group_by([c], c.from_user_id)
    |> select([c], %{
      user_id: c.from_user_id,
      contacts: fragment("array_agg(data -> 'contacts')")
    })
    |> T.Repo.all()
    |> Enum.map(fn %{contacts: contacts} = info ->
      %{info | contacts: group_contacts(contacts)}
    end)
    |> Enum.map(fn %{user_id: user_id, contacts: contacts} ->
      %{user_id: user_id, ig: contacts["instagram"]}
    end)
    |> Enum.reject(fn %{ig: ig} -> is_nil(ig) end)
    |> Enum.map(fn %{ig: igs} = i -> %{i | ig: filter_valid_igs(igs)} end)
    |> Enum.reject(fn %{ig: ig} -> ig == [] end)
  end

  defp filter_valid_igs(igs) do
    Enum.filter(igs, fn ig ->
      Regex.match?(
        ~r/^[A-Za-z0-9_](?:(?:[A-Za-z0-9_]|(?:\.(?!\.))){0,99}(?:[A-Za-z0-9_]))$/,
        ig |> String.replace(["@"], "") |> String.trim()
      )
    end)
  end

  def add_private_pages(contacts \\ @ig_contacts) do
    stories =
      T.Accounts.Profile
      |> where([p], p.user_id in ^Enum.map(contacts, & &1.user_id))
      |> select([p], {p.user_id, p.story})
      |> T.Repo.all()
      |> Map.new()

    Enum.reduce(contacts, [], fn %{user_id: user_id, ig: [ig]}, acc ->
      story = Map.fetch!(stories, user_id)

      if has_contacts?(story, ig) do
        acc
      else
        [%{user_id: user_id, story: add_private_page(story, ig)} | acc]
      end
    end)
  end

  def insert_new_stories(stories \\ add_private_pages()) do
    T.Repo.insert_all(T.Accounts.Profile, stories,
      on_conflict: {:replace, [:story]},
      conflict_target: :user_id
    )
  end

  defp add_private_page(story, ig) do
    %{"size" => [width, height] = size} = last_page = List.last(story)

    private_page = %{
      "blurred" => %{"s3_key" => "48f74064-ddc3-4072-89d7-cf0da9415d4e"},
      "background" => %{"color" => "#F97EB9"},
      "size" => size,
      "labels" => [
        %{
          "question" => "instagram",
          "answer" => ig,
          "position" => [width * 1 / 4, height * 1 / 3]
        }
      ]
    }

    story ++ [private_page]
  end

  defp has_contacts?(story, ig) do
    Enum.any?(story, fn %{"labels" => labels} ->
      Enum.any?(labels, fn label ->
        label["question"] == "instagram" and label["answer"] == ig
      end)
    end)
  end

  defp group_contacts(contacts) do
    contacts
    |> Enum.flat_map(fn contacts -> Map.to_list(contacts) end)
    |> Enum.group_by(fn {k, _} -> k end, fn {_k, v} -> v end)
    |> Enum.map(fn {k, v} -> {k, Enum.uniq(v)} end)
    |> Map.new()
  end
end
