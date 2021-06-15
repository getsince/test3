defmodule TWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use TWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import TWeb.ConnCase
      import T.Factory

      alias TWeb.Router.Helpers, as: Routes
      alias T.Repo

      # The default endpoint for testing
      @endpoint TWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(T.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(T.Repo, {:shared, self()})
    end

    Mox.stub_with(MockBot, StubBot)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
