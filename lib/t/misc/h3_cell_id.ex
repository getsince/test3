defmodule H3CellId do
  use Ecto.Type
  def type, do: :integer

  # round(:math.pow(2, 63)) - 1
  @i64_max 9_223_372_036_854_775_807

  def cast(cell_id) when is_integer(cell_id), do: {:ok, cell_id}

  # Everything else is a failure though
  def cast(_), do: :error

  def load(cell_id), do: {:ok, cell_id + @i64_max}

  def dump(cell_id) when is_integer(cell_id), do: {:ok, cell_id - @i64_max}
  def dump(_), do: :error
end
