defmodule T.AWS do
  @moduledoc false

  def config do
    Application.fetch_env!(:t, T.AWS)
  end

  def client do
    config = config()

    %AWS.Client{
      access_key_id: Keyword.fetch!(config, :access_key_id),
      secret_access_key: Keyword.fetch!(config, :secret_access_key),
      region: Keyword.fetch!(config, :region),
      http_client: {AWS.HTTPClient.Finch, finch_name: T.Finch}
    }
  end
end
