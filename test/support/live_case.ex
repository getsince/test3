defmodule TWeb.LiveCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Phoenix.ChannelTest
      import Phoenix.View
      import TWeb.ChannelCase
      import T.{Factory, DataCase}

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

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
