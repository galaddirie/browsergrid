ARG ELIXIR_VERSION=1.18.4
ARG DEBIAN_VERSION=bookworm-slim
ARG GO_VERSION=1.23
ARG PLAYWRIGHT_VERSION=1.47.0
ARG BROWSER_VERSION=latest


ARG ELIXIR_BUILDER_IMAGE="elixir:${ELIXIR_VERSION}"
ARG GO_BUILDER_IMAGE="golang:${GO_VERSION}"
ARG RUNTIME_IMAGE="debian:${DEBIAN_VERSION}"

# Elixir builder stage
FROM ${ELIXIR_BUILDER_IMAGE} AS elixir-builder

# Install build dependencies
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        build-essential \
        git \
        ca-certificates \
        locales \
        curl \
        gnupg && \
    update-ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*_*

# Configure UTF-8 support
RUN sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Install Node.js for assets
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*_*

WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && mix local.rebar --force

# Set build environment
ENV MIX_ENV=prod

# Get Elixir dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

# Copy and compile dependencies
COPY config config/
RUN mix deps.compile

# Copy application code
COPY priv priv/
COPY lib lib/

# Install and build assets
COPY assets/package.json assets/package-lock.json ./assets/
RUN cd assets && npm ci --only=production && cd ..
COPY assets assets/
RUN mix assets.deploy

# Compile the application
RUN mix compile

# Copy runtime config
COPY config/runtime.exs config/

# Build the release
RUN mix release

# Go builder stage for browsermux
FROM ${GO_BUILDER_IMAGE} AS go-builder

WORKDIR /app

# Copy Go module files
COPY docker/browsermux/go.mod docker/browsermux/go.sum ./

RUN go mod download

# Copy source code
COPY docker/browsermux/cmd ./cmd/
COPY docker/browsermux/internal ./internal/

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -o /browsermux ./cmd/main.go

# Runtime stage
FROM ${RUNTIME_IMAGE} AS runtime

LABEL org.opencontainers.image.source="https://github.com/autocrawlerHQ/browsergrid" \
      org.opencontainers.image.description="Production runtime for BrowserGrid sessions with Elixir app, browsermux, and Chrome"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    MIX_ENV=prod \
    HOME=/home/browseruser \
    BROWSERGRID_SESSION_DIR=/var/lib/browsergrid/sessions \
    BROWSERGRID_MEDIA_DIR=/var/lib/browsergrid/media \
    BROWSERGRID_PROFILES_DIR=/var/lib/browsergrid/profiles

# Install runtime dependencies (minimal for Elixir + browser libs)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    locales \
    tzdata \
    curl \
    gnupg \
    wget \
    unzip \
    libssl3 \
    libncurses5 \
    libtinfo5 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*_*

# Install full browser dependencies (from existing browser base)
RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor \
    xvfb \
    x11vnc \
    novnc \
    xterm \
    dbus-x11 \
    net-tools \
    software-properties-common \
    websockify \
    fontconfig \
    fonts-liberation \
    fonts-noto-color-emoji \
    sudo \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo-gobject2 \
    libgtk-3-0 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*_*

# Install Node.js 20 for Playwright
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*_*

# Configure locale
RUN localedef -i en_US -c -f UTF-8 en_US.UTF-8 && \
    ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata

WORKDIR /app

# Copy Elixir release
COPY --from=elixir-builder /app/_build/prod/rel/browsergrid ./

# Copy browsermux binary
COPY --from=go-builder /browsermux /usr/local/bin/browsermux
RUN chmod +x /usr/local/bin/browsermux

# Install Playwright and Chrome
RUN npm init -y && \
    npm install playwright@${PLAYWRIGHT_VERSION} && \
    npx playwright install --with-deps chrome && \
    rm -rf node_modules package.json package-lock.json

# Create non-root user
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} browseruser && \
    useradd -u ${UID} -g ${GID} -s /bin/bash -m -d ${HOME} browseruser && \
    echo "browseruser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Create writable directories
RUN mkdir -p ${BROWSERGRID_SESSION_DIR} \
    ${BROWSERGRID_MEDIA_DIR} \
    ${BROWSERGRID_PROFILES_DIR} \
    ${HOME}/.cache \
    ${HOME}/.config && \
    chown -R browseruser:browseruser /app \
    ${BROWSERGRID_SESSION_DIR} \
    ${BROWSERGRID_MEDIA_DIR} \
    ${BROWSERGRID_PROFILES_DIR} \
    ${HOME} && \
    chmod -R 755 ${HOME} \
    ${BROWSERGRID_SESSION_DIR} \
    ${BROWSERGRID_MEDIA_DIR} \
    ${BROWSERGRID_PROFILES_DIR}

# Copy entrypoint script
COPY docker/session-runtime/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER browseruser

# Expose port
EXPOSE 4000

# Healthcheck (assumes app has /health endpoint)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Use entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["start"]
