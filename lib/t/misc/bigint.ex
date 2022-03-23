defmodule BigInt do
  use Ecto.Type
  def type, do: :integer

  def cast(bigint) when is_integer(bigint), do: {:ok, bigint - 9_223_372_036_854_775_807}

  # Everything else is a failure though
  def cast(_), do: :error

  def load(data) do
    {:ok, Decimal.to_integer(data) + 9_223_372_036_854_775_807}
  end

  def dump(bigint) when is_integer(bigint), do: {:ok, bigint}
  def dump(_), do: :error
end
