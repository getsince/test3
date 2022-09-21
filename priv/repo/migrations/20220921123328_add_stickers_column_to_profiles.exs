defmodule T.Repo.Migrations.AddStickersColumnToProfiles do
  use Ecto.Migration
  import Ecto.Query
  alias T.Accounts.Profile

  def change do
    alter table(:profiles) do
      add :stickers, {:array, :string}
    end

    flush()

    Profile
    |> T.Repo.all()
    |> Enum.each(fn %Profile{user_id: user_id, story: story} ->
      stickers =
        case story do
          nil ->
            []

          _ ->
            story
            |> Enum.flat_map(fn %{"labels" => labels} ->
              labels
              |> Enum.reduce([], fn label, acc ->
                case label["answer"] do
                  nil ->
                    acc

                  "" ->
                    acc

                  answer ->
                    case label["question"] do
                      nil ->
                        acc

                      q when q in ["birthdate", "name", "height"] ->
                        acc

                      q
                      when q in [
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
                           ] ->
                        acc

                      _ ->
                        [answer | acc]
                    end
                end
              end)
            end)
        end

      Profile |> where(user_id: ^user_id) |> T.Repo.update_all(set: [stickers: stickers])
    end)
  end
end
