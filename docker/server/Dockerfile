ARG ELIXIR_VERSION=1.18.4
ARG DEBIAN_VERSION=bookworm-slim

ARG BUILDER_IMAGE="elixir:${ELIXIR_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends build-essential git ca-certificates locales curl gnupg \
    && update-ca-certificates \
    && apt-get clean \
    && rm -f /var/lib/apt/lists/*_*

# Configure UTF-8 locale in builder
RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

# Ensure UTF-8 is the default locale in the builder stage
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8"

# Ensure UTF-8 is the default locale in the runtime container
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8"

# Install Node.js 20.x for assets compilation
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

# Install npm dependencies first
COPY assets/package.json assets/package-lock.json assets/
RUN cd assets && npm ci

# Copy the rest of assets
COPY assets assets

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

WORKDIR "/app"

ENV MIX_ENV="prod"  

# Install runtime dependencies and configure UTF-8 in runner
# locales required to avoid latin1 warning from Erlang/Elixir
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends locales ca-certificates \
    && update-ca-certificates \
    && apt-get clean \
    && rm -f /var/lib/apt/lists/*_*

RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

COPY --from=builder /app/_build/${MIX_ENV}/rel/browsergrid ./


# Start the Phoenix server
CMD ["/app/bin/browsergrid", "start"]