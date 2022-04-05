defmodule T do
  @moduledoc false

  def aws_client(region \\ "eu-north-1") do
    # TODO fetch app env
    %AWS.Client{
      access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
      secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY"),
      region: region,
      http_client: {AWS.FinchHTTPClient, []}
    }
  end

  @task_sup T.TaskSupervisor
  def task_sup, do: @task_sup

  def async_stream(enumerable, fun, options \\ []) do
    Task.Supervisor.async_stream_nolink(@task_sup, enumerable, fun, options)
  end
end
