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
    alias Ecto.Adapters.SQL.Sandbox
    owner = Sandbox.start_owner!(T.Repo, shared: not tags[:async])

    :sys.replace_state(TWeb.UserSocket.Monitor, fn state ->
      Map.put(state, :task_exec, fn _task -> :ok end)
    end)

    # TODO still unsolved
    # https://github.com/phoenixframework/phoenix/issues/3619
    # https://github.com/phoenixframework/phoenix/pull/3856
    on_exit(fn ->
      Sandbox.stop_owner(owner)
    end)

    Mox.stub_with(MockBot, StubBot)

    :ok
  end

  alias T.Accounts
  import Phoenix.ChannelTest

  @endpoint TWeb.Endpoint

  def connected_socket(%Accounts.User{} = user) do
    token =
      user
      |> Accounts.generate_user_session_token("mobile")
      |> Accounts.UserToken.encoded_token()

    {:ok, socket} = connect(TWeb.UserSocket, %{"token" => token}, %{})
    socket
  end

  defmacro assert_presence_diff(pattern) do
    quote do
      assert_broadcast "presence_diff", unquote(pattern)
      assert_push "presence_diff", unquote(pattern)
    end
  end
end
