# defmodule T.Mailer.SendEmail do
#   @moduledoc """
#   Oban job for sending emails.
#   """

#   use Oban.Worker, queue: :emails, unique: [period: 30]
#   alias T.{Mailer, Mailer.Email}

#   @impl Oban.Worker
#   def perform(%Oban.Job{args: args}) do
#     email = build_email(args)

#     # https://github.com/thoughtbot/bamboo/blob/v1.3.0/lib/bamboo/adapters/send_grid_adapter.ex#L44-L46
#     # it will raise if sendgrid replies with any status code > 299, and the job would be retried
#     Mailer.deliver_now(email)

#     :ok
#   end

#   defp build_email(%{"type" => "added_to_waitlist", "locale" => locale, "email" => email}) do
#     Email.added_to_waitlist_email(email, locale: locale)
#   end
# end
