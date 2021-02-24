defmodule TWeb.ChannelHelpers do
  alias Phoenix.Socket

  def extract_user_ids(user_ids) do
    String.split(user_ids, ":")
  end

  defp downcased(user_id) when is_binary(user_id) do
    String.downcase(user_id)
  end

  defp downcased(user_ids) when is_list(user_ids) do
    Enum.map(user_ids, &downcased/1)
  end

  def other_user_id(%Socket{} = socket, [_1, _2] = user_ids) do
    [other_id] = downcased(user_ids) -- [current_user(socket).id]
    other_id
  end

  def verify_user_id(%Socket{} = socket, user_id) when is_binary(user_id) do
    user_id = downcased(user_id)
    ^user_id = current_user(socket).id
  end

  def verify_user_id(%Socket{} = socket, user_ids) when is_list(user_ids) do
    true = current_user(socket).id in downcased(user_ids)
  end

  def current_user(%Socket{assigns: assigns}) do
    assigns.current_user
  end

  def ensure_onboarded(%Socket{} = socket) do
    false = is_nil(current_user(socket).onboarded_at)
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
end
