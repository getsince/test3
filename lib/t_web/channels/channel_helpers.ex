defmodule TWeb.ChannelHelpers do
  def extract_user_ids(user_ids) do
    String.split(user_ids, ":")
  end

  def verify_user_id(%Phoenix.Socket{} = socket, user_id) when is_binary(user_id) do
    ^user_id = socket.assigns.user.id
  end

  def verify_user_id(%Phoenix.Socket{} = socket, user_ids) when is_list(user_ids) do
    true = socket.assigns.user.id in user_ids
  end
end
