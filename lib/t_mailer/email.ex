defmodule T.Mailer.Email do
  use Bamboo.Phoenix, view: TWeb.EmailView
  alias T.Mailer

  def added_to_waitlist_email(receiver_address, opts \\ []) do
    maybe_set_locale(opts)

    base_email(receiver_address)
    # TODO
    |> subject("waitlist")
    |> render("added_to_waitlist.text")
  end

  defp base_email(receiver) do
    new_email()
    |> to({"Наш пользователь", receiver})
    # TODO
    |> from({"Синсь", Mailer.our_address()})
  end

  defp maybe_set_locale(opts) do
    if locale = opts[:locale] do
      Gettext.put_locale(locale)
    end
  end
end
