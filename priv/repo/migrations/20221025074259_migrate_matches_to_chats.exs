defmodule T.Repo.Migrations.MigrateMatchesToChats do
  use Ecto.Migration
  import Ecto.Query
  alias Ecto.Multi
  alias T.Repo
  alias T.Matches.{Match, Interaction}
  alias T.Chats.{Chat, Message}

  def change do
    Match
    |> Repo.all()
    |> Enum.each(fn %Match{
                      id: match_id,
                      user_id_1: uid1,
                      user_id_2: uid2,
                      inserted_at: inserted_at
                    } ->
      Interaction
      |> where(match_id: ^match_id)
      |> Repo.all()
      |> case do
        [] ->
          :ok

        interactions ->
          Multi.new()
          |> Multi.insert(:chat, %Chat{
            id: match_id,
            user_id_1: uid1,
            user_id_2: uid2,
            matched: true,
            inserted_at: inserted_at
          })
          |> Multi.insert_all(
            :messages,
            Message,
            interactions
            |> Enum.filter(fn %Interaction{data: data} ->
              case data["sticker"]["question"] do
                "drawing" -> false
                _ -> true
              end
            end)
            |> Enum.map(fn %Interaction{
                             id: interaction_id,
                             from_user_id: from,
                             to_user_id: to,
                             data: data,
                             seen: seen
                           } ->
              inserted_at = datetime(interaction_id)

              sticker = data["sticker"]

              message_data =
                case sticker["question"] do
                  nil -> sticker |> Map.take(["value"]) |> Map.put("question", "text")
                  _ -> sticker |> Map.drop(["zoom", "position", "rotation"])
                end

              %{
                id: interaction_id,
                chat_id: match_id,
                from_user_id: from,
                to_user_id: to,
                data: message_data,
                seen: seen,
                inserted_at: inserted_at
              }
            end)
          )
          |> Repo.transaction()
      end
    end)
  end

  defp datetime(<<_::288>> = uuid) do
    datetime(Ecto.Bigflake.UUID.dump!(uuid))
  end

  defp datetime(<<unix::64, _rest::64>>) do
    unix |> DateTime.from_unix!(:millisecond) |> DateTime.truncate(:second) |> DateTime.to_naive()
  end
end
