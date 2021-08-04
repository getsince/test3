FROM hexpm/elixir:1.12.2-erlang-24.0.5-alpine-3.14.0 as build

# install build dependencies
RUN apk add --no-cache --update git build-base nodejs yarn

# prepare build dir
RUN mkdir /app
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
  mix local.rebar --force

# set build ENV
ENV MIX_ENV=prod

# install mix dependencies
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/
RUN mix deps.get
RUN mix deps.compile

# build project
COPY priv priv
COPY lib lib
RUN mix sentry_recompile
COPY config/runtime.exs config/

# build assets
COPY assets assets
RUN cd assets && yarn install && yarn deploy
RUN mix phx.digest

# build release
RUN mix release

# prepare release image
FROM alpine:3.14.0 AS app
RUN apk add --no-cache --update bash openssl libgcc libstdc++

RUN mkdir /app
WORKDIR /app

COPY --from=build /app/_build/prod/rel/t ./
RUN chown -R nobody: /app
USER nobody

ENV HOME=/app

CMD /app/bin/t start
