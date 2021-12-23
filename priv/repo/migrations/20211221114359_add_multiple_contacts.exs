defmodule T.Repo.Migrations.AddMultipleContacts do
  use Ecto.Migration
  import Ecto.Query

  def change do
    alter table(:match_contact) do
      add :contacts, :jsonb
    end

    flush()

    "match_contact"
    |> update([c],
      set: [contacts: fragment("jsonb_build_object(?, ?)", c.contact_type, c.value)]
    )
    |> T.Repo.update_all([])

    flush()

    alter table(:match_contact) do
      remove :contact_type
      remove :value
    end
  end
end
