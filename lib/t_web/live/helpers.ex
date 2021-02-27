defmodule TWeb.LiveHelpers do
  @moduledoc false
  import Phoenix.LiveView.Helpers

  @doc """
  Renders a component inside the `TWeb.ModalComponent` component.

  The rendered modal receives a `:return_to` option to properly update
  the URL when the modal is closed.

  ## Examples

      <%= live_modal @socket, TWeb.UserLive.FormComponent,
        id: @user.id || :new,
        title: gettext("User Form"),
        action: @live_action,
        user: @user,
        return_to: Routes.user_path(@socket, :index) %>
  """
  def live_modal(_socket, component, opts) do
    path = Keyword.fetch!(opts, :return_to)
    title = Keyword.fetch!(opts, :title)
    modal_opts = [id: :modal, title: title, return_to: path, component: component, opts: opts]
    live_component(_socket = nil, TWeb.ModalComponent, modal_opts)
  end
end
