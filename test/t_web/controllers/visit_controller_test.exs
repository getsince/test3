defmodule TWeb.VisitControllerTest do
  use TWeb.ConnCase, async: true
  alias T.Visits.Visit

  describe "POST /api/visited" do
    test "with valid attrs", %{conn: conn} do
      conn = post(conn, "/api/visited", %{"id" => "ecbd5802-6a81-48c1-92d8-068c52d94ede"})
      assert conn.status == 201
      assert Repo.get_by(Visit, id: "ecbd5802-6a81-48c1-92d8-068c52d94ede")
    end
  end
end
