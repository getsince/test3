# defmodule T.Mailer do
#   use Bamboo.Mailer, otp_app: :t
#   alias __MODULE__.SendEmail

#   @doc false
#   @spec our_address :: String.t()
#   def our_address do
#     Application.fetch_env!(:t, __MODULE__)[:our_address] ||
#       raise("need :our_address set in #{__MODULE__} config")
#   end

#   def schedule_added_to_waitlist_email(email) when is_binary(email) do
#     %{"type" => "added_to_waitlist", "email" => email, "locale" => Gettext.get_locale()}
#     |> SendEmail.new()
#     |> Oban.insert!()
#   end
# end
