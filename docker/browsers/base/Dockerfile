# Stage 1: Build browsermux binary
FROM golang:1.23-alpine AS browsermux-builder

WORKDIR /app

COPY ./docker/browsermux/go.mod ./docker/browsermux/go.sum ./

RUN go mod download

COPY ./docker/browsermux/cmd/ ./cmd/
COPY ./docker/browsermux/internal/ ./internal/

RUN CGO_ENABLED=0 GOOS=linux go build -o /browsermux ./cmd/main.go

# Stage 2: Base browser image
FROM ubuntu:22.04 AS browser-base

LABEL org.opencontainers.image.source="https://github.com/autocrawlerHQ/browsergrid"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles
ENV HOME=/home/user
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Screen environment
ENV DISPLAY=:1
ENV VNC_PORT=5900
ENV VNC_PASSWORD=password
ENV RESOLUTION_WIDTH=1920
ENV RESOLUTION_HEIGHT=1080
ENV RESOLUTION_DEPTH=24
ENV RESOLUTION=${RESOLUTION_WIDTH}x${RESOLUTION_HEIGHT}x${RESOLUTION_DEPTH}

# Set static UID and GID for the browser user
ENV UID=1000
ENV GID=1000

ENV REMOTE_DEBUGGING_PORT=61000
ENV SW_SERVER_PORT=8082

# Install system packages
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
    locales \
    tzdata \
    ca-certificates \
    wget \
    curl \
    pwgen \
    socat \
    tar \
    unzip \
    gnupg \
    xdg-utils \
    x11-utils \
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
    nginx \
    sudo \
    && apt-get autoclean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*

# Install fonts
RUN apt-get update && apt-get -y --no-install-recommends install \
    fontconfig \
    fonts-freefont-ttf \
    fonts-gfs-neohellenic \
    fonts-indic \
    fonts-ipafont-gothic \
    fonts-kacst \
    fonts-liberation \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    fonts-roboto \
    fonts-thai-tlwg \
    fonts-ubuntu \
    fonts-wqy-zenhei \
    fonts-open-sans \
    ttf-mscorefonts-installer \
    cabextract \
    && fc-cache -f -v \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Configure locale and timezone
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
RUN ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata

# Create directories
RUN mkdir -p /opt/browsergrid/scripts

# Create non-root user with static UID/GID
RUN groupadd -g ${GID} browseruser && \
    useradd -u ${UID} -g ${GID} -s /bin/bash -m -d ${HOME} browseruser && \
    echo "browseruser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Copy browsermux binary from builder stage
COPY --from=browsermux-builder /browsermux /usr/local/bin/browsermux
RUN chmod +x /usr/local/bin/browsermux

# Copy scripts and configs
COPY docker/scripts/ /opt/browsergrid/scripts/
COPY docker/browsers/base/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/browsers/base/entrypoint.sh /usr/local/bin/
COPY docker/browsers/base/nginx/nginx.conf /etc/nginx/sites-available/browsergrid
COPY docker/browsers/base/nginx/setup_nginx.sh /usr/local/bin/

# Configure nginx properly
RUN rm -f /etc/nginx/sites-enabled/default && \
    rm -f /etc/nginx/conf.d/default.conf && \
    ln -s /etc/nginx/sites-available/browsergrid /etc/nginx/sites-enabled/browsergrid

# Set permissions
RUN chmod -R +x /opt/browsergrid/scripts/ && \
    chmod +x /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/setup_nginx.sh && \
    chown -R browseruser:browseruser /opt/browsergrid/scripts

# Set up user directories
RUN mkdir -p ${HOME}/.cache && \
    mkdir -p ${HOME}/.config && \
    mkdir -p ${HOME}/.npm && \
    chown -R browseruser:browseruser /opt/browsergrid && \
    chown -R browseruser:browseruser ${HOME} && \
    chmod -R 755 ${HOME}

# Stage 3: Chrome browser
FROM browser-base AS chrome-browser

LABEL org.opencontainers.image.description="Chrome browser with embedded browsermux for Browsergrid"
LABEL org.opencontainers.image.version="${BROWSER_VERSION}"
LABEL browsergrid.browser.version="${BROWSER_VERSION}"
LABEL browsergrid.playwright.version="${PLAYWRIGHT_VERSION}"

ARG PLAYWRIGHT_VERSION=latest
ARG BROWSER_VERSION=latest

# Set working directory before npm operations
WORKDIR ${HOME}

# Install Playwright and Chrome
RUN npm i playwright@${PLAYWRIGHT_VERSION}
RUN npx playwright install --with-deps chrome

# Create Chrome data directory with proper permissions
RUN mkdir -p ${HOME}/data-dir && \
    chown -R browseruser:browseruser ${HOME}/data-dir && \
    chmod -R 755 ${HOME}/data-dir

# Copy Chrome-specific scripts
COPY docker/browsers/chrome/start.sh /start.sh
COPY docker/browsers/chrome/docker-healthcheck /usr/local/bin/docker-healthcheck
RUN chmod +x /start.sh /usr/local/bin/docker-healthcheck && \
    chown browseruser:browseruser /start.sh

# Expose all required ports
EXPOSE 80

HEALTHCHECK --interval=5s --timeout=3s --retries=3 CMD ["docker-healthcheck"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["su", "-c", "/start.sh", "browseruser"]