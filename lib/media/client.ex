defmodule T.Media.Client do
  @callback list_objects(String.t()) :: [map]

  @adapter Application.compile_env!(:t, [__MODULE__, :adapter])

  def list_objects(bucket) do
    @adapter.list_objects(bucket)
  end
end
