Application.put_env(:ex_unit, :assert_receive_timeout, 1000)
ExUnit.configure(exclude: [:integration])
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(T.Repo, :manual)
