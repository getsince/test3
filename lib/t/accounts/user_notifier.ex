defmodule T.Accounts.UserNotifier do
  import TWeb.Gettext

  @adapter Application.compile_env!(:t, __MODULE__)[:adapter] ||
             raise("Need :adapter set for #{__MODULE__}")

  @callback deliver(phone_number :: String.t(), body :: String.t()) :: {:ok, any}

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(phone_number, code) when is_binary(phone_number) do
    @adapter.deliver(
      phone_number,
      dgettext("notification", "Your Since code is: %{code}.", code: code)
    )
  end
end
