defmodule T.Matches.ContactsTest do
  use T.DataCase, async: true
  use Oban.Testing, repo: T.Repo
  alias T.Matches

  describe "save_contact_click/2" do
    setup [:with_profiles, :with_match]

    test "saves contact_click events", %{match: match} do
      assert {:ok, _event} = Matches.save_contact_click(match.id)
      assert [%{expiration_date: nil}] = Matches.list_matches(match.user_id_1, default_location())
      assert [%{expiration_date: nil}] = Matches.list_matches(match.user_id_2, default_location())
    end
  end

  defp with_profiles(_context) do
    {:ok, profiles: insert_list(2, :profile, hidden?: false)}
  end

  defp with_match(%{profiles: [p1, p2]}) do
    {:ok, match: insert(:match, user_id_1: p1.user_id, user_id_2: p2.user_id)}
  end
end
