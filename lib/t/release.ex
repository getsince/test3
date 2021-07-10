defmodule T.Release do
  @moduledoc false
  @app :t
  require Logger

  defmodule Migrator do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def init(_opts) do
      T.Release.migrate()
      :ignore
    end
  end

  def migrate do
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.load(@app)
    Application.fetch_env!(@app, :ecto_repos)
  end

  def mark_ready do
    Application.put_env(@app, :ready?, true)
  end

  @spec ready? :: boolean | nil
  def ready? do
    Application.get_env(@app, :ready?)
  end

  {sha, 0} = System.cmd("git", ["rev-parse", "HEAD"])

  def git_sha do
    unquote(String.trim(sha))
  end

  {author, 0} = System.cmd("git", ~w[log -1 --pretty=format:'%an'])

  def git_author do
    unquote(author |> String.trim_leading("'") |> String.trim_trailing("'"))
  end
end
