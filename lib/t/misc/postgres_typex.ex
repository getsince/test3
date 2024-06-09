Postgrex.Types.define(
  T.PostgresTypes,
  [Geo.PostGIS.Extension | Ecto.Adapters.Postgres.extensions()],
  json: :json
)
