defmodule T.Repo do
  use Ecto.Repo,
    otp_app: :t,
    adapter: Ecto.Adapters.Postgres

  def transact(f) do
    transaction(fn ->
      case f.() do
        {:ok, result} -> result
        {:error, reason} -> rollback(reason)
      end
    end)
  end
end
