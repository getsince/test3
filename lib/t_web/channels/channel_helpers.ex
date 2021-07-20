defmodule TWeb.ChannelHelpers do
  alias Phoenix.Socket
  alias T.Accounts.User

  defp downcased(user_id) when is_binary(user_id) do
    String.downcase(user_id)
  end

  @spec verify_user_id(Phoenix.Socket.t(), Ecto.UUID.t()) :: Ecto.UUID.t()
  def verify_user_id(%Socket{} = socket, user_id) when is_binary(user_id) do
    user_id = downcased(user_id)
    ^user_id = current_user(socket).id
  end

  def current_user(%Socket{assigns: assigns}) do
    %User{} = assigns.current_user
  end

  def report(socket, report) do
    %{"reason" => reason, "profile_id" => reported_user_id} = report
    %{current_user: reporter} = socket.assigns

    case T.Accounts.report_user(reporter.id, reported_user_id, reason) do
      :ok ->
        {:reply, :ok, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        rendered = Phoenix.View.render(TWeb.ErrorView, "changeset.json", changeset: changeset)
        {:reply, {:error, %{report: rendered}}, socket}
    end
  end

  def extract_timestamp(raw) do
    if raw do
      {:ok, dt, 0} = DateTime.from_iso8601(raw)
      dt
    end
  end
end
