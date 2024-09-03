defmodule Since.Repo do
  use Ecto.Repo,
    otp_app: :since,
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
