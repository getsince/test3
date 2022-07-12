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

  @spec valid_user_topic?(Phoenix.Socket.t(), Ecto.UUID.t()) :: boolean()
  def valid_user_topic?(%Socket{} = socket, user_id) do
    current_user(socket).id == downcased(user_id)
  end

  def current_user(%Socket{assigns: assigns}) do
    %User{} = assigns.current_user
  end

  def me(%Socket{assigns: %{current_user: %User{} = me}}), do: me
  def me_id(%Socket{assigns: %{current_user: %User{id: id}}}), do: id

  def report(socket, params) do
    {reason, reported_user_id} = report_params(params)
    %{current_user: reporter} = socket.assigns

    case T.Accounts.report_user(reporter.id, reported_user_id, reason) do
      :ok ->
        {:reply, :ok, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        rendered = Phoenix.View.render(TWeb.ErrorView, "changeset.json", changeset: changeset)
        {:reply, {:error, %{report: rendered}}, socket}
    end
  end

  defp report_params(%{"reason" => reason, "user_id" => user_id}), do: {reason, user_id}
  defp report_params(%{"reason" => reason, "profile_id" => user_id}), do: {reason, user_id}
  defp report_params(%{"report" => params}), do: report_params(params)

  def maybe_put(map, _key, nil), do: map
  def maybe_put(map, _key, false), do: map
  def maybe_put(map, _key, []), do: map
  def maybe_put(map, key, value), do: Map.put(map, key, value)

  def maybe_put_with_empty_list(map, _key, nil), do: map
  def maybe_put_with_empty_list(map, _key, false), do: map
  def maybe_put_with_empty_list(map, key, value), do: Map.put(map, key, value)

  @spec utc_now(Socket.t()) :: DateTime.t()
  def utc_now(%Socket{private: %{freeze_time: f}}) when is_function(f, 0), do: f.()
  def utc_now(%Socket{}), do: DateTime.utc_now()

  def alert(title, body) do
    %{title: title, body: body}
  end
end
