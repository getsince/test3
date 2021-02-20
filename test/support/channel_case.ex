defmodule TWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use TWeb.ChannelCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import Phoenix.View
      import TWeb.ChannelCase
      import T.{Factory, DataCase}

      alias T.Repo

      # The default endpoint for testing
      @endpoint TWeb.Endpoint
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(T.Repo)

    if tags[:async] do
      monitor = Process.whereis(TWeb.UserSocket.Monitor)
      Ecto.Adapters.SQL.Sandbox.allow(T.Repo, self(), monitor)
    else
      Ecto.Adapters.SQL.Sandbox.mode(T.Repo, {:shared, self()})
    end

    :ok
  end

  alias T.Accounts
  import Phoenix.ChannelTest

  @endpoint TWeb.Endpoint

  def connected_socket(user) do
    token =
      user
      |> Accounts.generate_user_session_token("mobile")
      |> Accounts.UserToken.encoded_token()

    {:ok, socket} = connect(TWeb.UserSocket, %{"token" => token}, %{})
    socket
  end
end
