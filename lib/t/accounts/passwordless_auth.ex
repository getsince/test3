defmodule T.Accounts.PasswordlessAuth do
  @moduledoc false

  alias T.{Repo, Accounts.SMSCode}
  import Ecto.Query

  # TODO rate limit
  @spec generate_code(String.t()) :: String.t()
  def generate_code(phone_number) do
    code = random_code(4)

    Repo.insert!(%SMSCode{phone_number: phone_number, code: code},
      on_conflict: :replace_all,
      conflict_target: [:phone_number]
    )

    code
  end

  @type verification_failed_reason ::
          :attempt_blocked | :code_expired | :incorrect_code

  @spec verify_code(String.t(), String.t()) :: :ok | {:error, verification_failed_reason}
  def verify_code(phone, code) do
    with {:fetch, %SMSCode{} = code_info} <- {:fetch, fetch_sms_code(phone, code)},
         {:attempts, true} <- {:attempts, has_more_attempts?(code_info)},
         {:expired, false} <- {:expired, code_expired?(code_info)} do
      remove_code(code_info)
      :ok
    else
      {:fetch, nil} -> {:error, :incorrect_code}
      {:attempts, false} -> {:error, :attempt_blocked}
      {:expired, true} -> {:error, :code_expired}
    end
  end

  defp has_more_attempts?(%SMSCode{attempts: attempts}) do
    attempts < 6
  end

  @doc """

      iex> code_expired?(~N[2021-06-30 14:41:03], ~N[2021-06-30 14:41:03])
      false

      iex> code_expired?(~N[2021-06-30 14:32:03], ~N[2021-06-30 14:41:03])
      true

      iex> code_expired?(~N[2021-06-30 14:41:03], ~N[2021-06-30 14:41:10])
      false

  """
  def code_expired?(dt_or_sms_info, reference \\ NaiveDateTime.utc_now())

  def code_expired?(%NaiveDateTime{} = inserted_at, reference) do
    NaiveDateTime.diff(reference, inserted_at) >= 300
  end

  def code_expired?(%SMSCode{inserted_at: inserted_at}, reference) do
    code_expired?(inserted_at, reference)
  end

  defp fetch_sms_code(phone_number, code) do
    SMSCode
    |> where(phone_number: ^phone_number)
    |> where(code: ^code)
    |> update([c], set: [attempts: c.attempts + 1])
    |> select([c], c)
    |> Repo.update_all([])
    |> case do
      {0, _} -> nil
      {1, [%SMSCode{} = code]} -> code
    end
  end

  defp remove_code(%SMSCode{phone_number: phone_number, code: code}) do
    SMSCode
    |> where(phone_number: ^phone_number)
    |> where(code: ^code)
    |> Repo.delete_all()
  end

  def random_code(code_length) do
    1..code_length
    |> Enum.map(fn _ -> :rand.uniform(10) - 1 end)
    |> Enum.join()
  end

  def prune(ttl_seconds) do
    SMSCode
    |> where([c], c.inserted_at < fragment("now() - ? * interval '1 second'", ^ttl_seconds))
    |> Repo.delete_all()
  end
end
