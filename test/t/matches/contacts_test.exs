defmodule T.Matches.ContactsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo

  alias T.Matches
  alias T.Matches.MatchContact

  describe "save_contact_offer/3 for invalid match" do
    setup [:with_profiles]

    @contact %{"contact_type" => "telegram", "value" => "@durov"}

    test "with non-existent match", %{profiles: [p1, _]} do
      match = Ecto.UUID.generate()

      assert_raise Ecto.NoResultsError, fn ->
        Matches.save_contact_offer_for_match(p1.user_id, match, @contact)
      end
    end

    test "with match we are not part of", %{profiles: [p1, p2]} do
      p3 = insert(:profile, hidden?: false)
      match = insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)

      assert_raise Ecto.NoResultsError, fn ->
        Matches.save_contact_offer_for_match(p3.user_id, match.id, @contact)
      end

      match_event = Matches.MatchEvent |> T.Repo.all()

      assert length(match_event) == 0
    end
  end

  describe "save_contact_offer/3" do
    setup [:with_profiles, :with_match]

    test "with empty contact", %{profiles: [p1, _], match: match} do
      assert {:error, %Ecto.Changeset{valid?: false} = changeset} =
               Matches.save_contact_offer_for_match(p1.user_id, match.id, %{
                 "contact_type" => "",
                 "value" => ""
               })

      assert errors_on(changeset) == %{
               contact_type: ["can't be blank"],
               value: ["can't be blank"]
             }
    end

    # TODO unsupported contact type / value
  end

  describe "save_contact_offer/3 side-effects" do
    setup [:with_profiles]

    setup %{profiles: [_p1, p2]} do
      Matches.subscribe_for_user(p2.user_id)
    end

    setup [:with_match, :with_contact_offer]

    test "push notification is scheduled for mate", %{
      profiles: [%{user_id: offerer_id}, %{user_id: receiver_id}],
      match: %{id: match_id}
    } do
      assert [
               %Oban.Job{
                 args: %{
                   "match_id" => ^match_id,
                   "receiver_id" => ^receiver_id,
                   "offerer_id" => ^offerer_id,
                   "type" => "contact_offer"
                 }
               }
             ] = all_enqueued(worker: T.PushNotifications.DispatchJob)
    end

    test "offer is broadcast via pubsub to mate", %{profiles: [_p1, %{user_id: receiver_id}]} do
      assert_receive {Matches, [:contact, :offered], %MatchContact{} = contact}

      assert contact.contact_type == "whatsapp"
      assert contact.value == "+55555555555"

      assert contact.picker_id == receiver_id
    end
  end

  describe "counter-offer" do
    setup [:with_profiles, :with_match]

    test "on counter-offer, contact is overwritten", %{profiles: [_p1, p2], match: match} do
      assert %MatchContact{} =
               insert(:match_contact,
                 contact_type: "instagram",
                 value: "zyzz",
                 match: match,
                 picker: p2.user
               )

      assert {:ok, %MatchContact{contact_type: "whatsapp", value: "+66666666666"}} =
               Matches.save_contact_offer_for_match(
                 p2.user_id,
                 match.id,
                 %{"contact_type" => "whatsapp", "value" => "+66666666666"}
               )
    end
  end

  describe "contact_cancel" do
    setup [:with_profiles, :with_match]

    test "contact is deleted", %{profiles: [_p1, p2], match: match} do
      assert %MatchContact{} =
               insert(:match_contact,
                 contact_type: "phone",
                 value: "+77777777777",
                 match: match,
                 picker: p2.user
               )

      assert :ok = Matches.cancel_contact_for_match(p2.user_id, match.id)

      match_id = match.id

      assert MatchContact |> where(match_id: ^match_id) |> T.Repo.all() == []
    end
  end

  defp with_profiles(_context) do
    {:ok, profiles: insert_list(2, :profile, hidden?: false)}
  end

  defp with_match(%{profiles: [p1, p2]}) do
    {:ok, match: insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)}
  end

  defp with_contact_offer(%{profiles: [p1, _p2], match: match}) do
    contact = %{"contact_type" => "whatsapp", "value" => "+55555555555"}

    assert {:ok, %MatchContact{} = match_contact} =
             Matches.save_contact_offer_for_match(
               p1.user_id,
               match.id,
               contact
             )

    {:ok, match_contact: match_contact}
  end
end
