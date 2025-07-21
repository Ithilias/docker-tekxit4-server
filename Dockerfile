FROM eclipse-temurin:17-jre-focal

ARG VERSION="16.4.4"

ENV USER=minecraft
ENV UID=1000
ENV JAVA_XMS=1G
ENV JAVA_XMX=4G
ENV JAVA_ADDITIONAL_ARGS=""

# Install necessary packages and clean up
RUN apt-get update && \
    apt-get install -y unzip curl gosu && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Download, setup rcon-cli, and clean up
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        aarch64) ARCH="arm64" ;; \
        x86_64) ARCH="amd64" ;; \
    esac && \
    LATEST_VERSION=$(curl -sSL https://api.github.com/repos/itzg/rcon-cli/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') && \
    echo "LATEST_VERSION: ${LATEST_VERSION}" && \
    echo "ARCH: ${ARCH}" && \
    curl -sSL "https://github.com/itzg/rcon-cli/releases/download/${LATEST_VERSION}/rcon-cli_${LATEST_VERSION}_linux_${ARCH}.tar.gz" -o rcon-cli.tar.gz && \
    tar -xzf rcon-cli.tar.gz rcon-cli && \
    mv rcon-cli /usr/local/bin && \
    rm rcon-cli.tar.gz

# Add entrypoint script
COPY ./scripts/entrypoint.sh /entrypoint
RUN chmod +x /entrypoint

# Create user, download and unpack Tekxit server files, and set up directories
RUN adduser --disabled-password --gecos "" --uid "${UID}" "${USER}" && \
    mkdir /tekxit-server && \
    chown -R "${USER}" /tekxit-server && \
    curl -sSL "https://tekxit.b-cdn.net/downloads/tekxit4/${VERSION}Tekxit4Server.zip" -o tekxit-server.zip && \
    unzip tekxit-server.zip && \
    mv ${VERSION}Tekxit4Server/* /tekxit-server && \
    rmdir ${VERSION}Tekxit4Server && \
    rm tekxit-server.zip

# Add update indicator
RUN touch /tekxit-server/update_indicator

WORKDIR /data

EXPOSE 25565
EXPOSE 25575
ENTRYPOINT ["/bin/bash", "/entrypoint"]
