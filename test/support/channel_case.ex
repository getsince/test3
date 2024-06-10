defmodule SinceWeb.ChannelCase do
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
  by setting `use SinceWeb.ChannelCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import Phoenix.View
      import SinceWeb.ChannelCase
      import T.{Factory, DataCase}

      alias Since.Repo

      # The default endpoint for testing
      @endpoint SinceWeb.Endpoint
    end
  end

  setup tags do
    alias Ecto.Adapters.SQL.Sandbox
    owner = Sandbox.start_owner!(Since.Repo, shared: not tags[:async])

    :sys.replace_state(SinceWeb.UserSocket.Monitor, fn state ->
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

  alias Since.Accounts
  import Phoenix.ChannelTest

  @endpoint SinceWeb.Endpoint

  def connected_socket(%Accounts.User{} = user, vsn \\ "8.3.0") do
    token =
      user
      |> Accounts.generate_user_session_token("mobile")
      |> Accounts.UserToken.encoded_token()

    {:ok, socket} =
      connect(SinceWeb.UserSocket, %{"token" => token, "version" => vsn}, connect_info: %{})

    socket
  end

  @spec freeze_time(Phoenix.Socket.t(), DateTime.t()) :: Phoenix.Socket.t()
  def freeze_time(%Phoenix.Socket{channel_pid: channel_pid}, utc_datetime)
      when is_pid(channel_pid) do
    :sys.replace_state(channel_pid, fn %Phoenix.Socket{private: private} = socket ->
      %{socket | private: Map.put(private, :freeze_time, fn -> utc_datetime end)}
    end)
  end

  def freeze_time(%Phoenix.Socket{private: private} = socket, utc_datetime) do
    %{socket | private: Map.put(private, :freeze_time, fn -> utc_datetime end)}
  end
end
