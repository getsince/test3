defmodule T.Matches.Match do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, Ecto.Bigflake.UUID, autogenerate: true}
  @foreign_key_type Ecto.Bigflake.UUID
  schema "matches" do
    field :user_id_1, Ecto.Bigflake.UUID
    field :user_id_2, Ecto.Bigflake.UUID

    # TODO
    field :profile, :map, virtual: true

    # TODO :interactions?
    has_one :timeslot, T.Matches.Timeslot
    has_one :contact, T.Matches.MatchContact

    field :expiration_date, :utc_datetime, virtual: true
    field :audio_only, :boolean, virtual: true
    field :last_interaction_id, Ecto.Bigflake.UUID, virtual: true
    field :seen, :boolean, virtual: true

    # embeds_one :slot_offer, Timeslot do
    #   field :offerer, Ecto.Bigflake.UUID
    #   field :slots, {:array, DateTime}
    #   field :accepted_slot, DateTime
    # end

    timestamps(updated_at: false)
  end
end
