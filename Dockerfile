FROM eclipse-temurin:17-jre-jammy

ARG VERSION="16.8.8"
ARG BUILDTIME
ARG REVISION

LABEL org.opencontainers.image.title="docker-tekxit4-server" \
      org.opencontainers.image.description="Docker image for a Tekxit 4 Minecraft server" \
      org.opencontainers.image.source="https://github.com/Ithilias/docker-tekxit4-server" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILDTIME}" \
      org.opencontainers.image.revision="${REVISION}"

ENV USER=minecraft
ENV UID=1000
ENV JAVA_XMS=1G
ENV JAVA_XMX=4G
ENV JAVA_ADDITIONAL_ARGS=""

# Install necessary packages and clean up
RUN apt-get update && \
    apt-get install -y unzip curl gosu jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download, setup rcon-cli, and clean up
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        aarch64) ARCH="arm64" ;; \
        x86_64) ARCH="amd64" ;; \
    esac && \
    LATEST_VERSION=$(curl -sSL https://api.github.com/repos/itzg/rcon-cli/releases/latest | jq -r '.tag_name') && \
    echo "LATEST_VERSION: ${LATEST_VERSION}" && \
    echo "ARCH: ${ARCH}" && \
    CHECKSUM_FILE="rcon-cli_${LATEST_VERSION}_checksums.txt" && \
    RCON_ARCHIVE="rcon-cli_${LATEST_VERSION}_linux_${ARCH}.tar.gz" && \
    curl -sSL "https://github.com/itzg/rcon-cli/releases/download/${LATEST_VERSION}/${CHECKSUM_FILE}" -o "${CHECKSUM_FILE}" && \
    curl -sSL "https://github.com/itzg/rcon-cli/releases/download/${LATEST_VERSION}/rcon-cli_${LATEST_VERSION}_linux_${ARCH}.tar.gz" -o rcon-cli.tar.gz && \
    grep " ${RCON_ARCHIVE}$" "${CHECKSUM_FILE}" | sed 's/  .*$/  rcon-cli.tar.gz/' | sha256sum -c - && \
    tar -xzf rcon-cli.tar.gz rcon-cli && \
    mv rcon-cli /usr/local/bin && \
    rm rcon-cli.tar.gz "${CHECKSUM_FILE}"

# Create user, download and unpack Tekxit server files, and set up directories
RUN adduser --disabled-password --gecos "" --uid "${UID}" "${USER}" && \
    mkdir /tekxit-server && \
    chown -R "${USER}" /tekxit-server && \
    if curl -sSL --head --fail "https://tekxit.b-cdn.net/downloads/tekxit4/${VERSION}Tekxit4Server.zip" > /dev/null 2>&1; then \
        curl -sSL "https://tekxit.b-cdn.net/downloads/tekxit4/${VERSION}Tekxit4Server.zip" -o tekxit-server.zip; \
    else \
        DOWNLOAD_URL=$(curl -sSL "https://api.technicpack.net/modpack/tekxit-4-official?build=latest" | jq -r '.serverPackUrl') && \
        curl -sSL "${DOWNLOAD_URL}" -o tekxit-server.zip; \
    fi && \
    unzip tekxit-server.zip && \
    EXTRACTED_DIR=$(unzip -Z -1 tekxit-server.zip | head -1 | cut -d'/' -f1) && \
    mv "${EXTRACTED_DIR}"/* /tekxit-server && \
    rmdir "${EXTRACTED_DIR}" && \
    rm tekxit-server.zip

# Add update indicator
RUN touch /tekxit-server/update_indicator && \
    echo "${VERSION}" > /tekxit-server/.tekxit-version

# Add entrypoint script (after the download layer so script edits don't invalidate it)
COPY --chmod=755 ./scripts/entrypoint.sh /entrypoint

WORKDIR /data

EXPOSE 25565
EXPOSE 25575
EXPOSE 24454/udp
HEALTHCHECK --start-period=10m --interval=30s --timeout=10s --retries=3 CMD rcon-cli --host localhost --port "${RCON_PORT:-25575}" --password "${RCON_PASSWORD}" list > /dev/null
ENTRYPOINT ["/bin/bash", "/entrypoint"]
