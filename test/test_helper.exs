{:ok, _} = Application.ensure_all_started(:ex_machina)
Application.put_env(:ex_unit, :assert_receive_timeout, 1000)
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(T.Repo, :manual)
