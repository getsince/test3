Postgrex.Types.define(
  Since.PostgresTypes,
  [Geo.PostGIS.Extension | Ecto.Adapters.Postgres.extensions()],
  json: Jason
)
