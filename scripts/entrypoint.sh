#!/bin/bash
set -euo pipefail

# Constants for default RCON values
DEFAULT_RCON_PORT=25575

# Set later once the server is launched; may still be empty if TERM arrives
# during startup (set -u would otherwise crash the shutdown handler)
SERVER_PID=""

# Function to handle TERM signal
shutdown_handler() {
    echo "TERM signal received, attempting to shut down the server..."

    # Try to gracefully shut down the server using rcon-cli
    if rcon-cli --host localhost --port "${RCON_PORT:-$DEFAULT_RCON_PORT}" --password "${RCON_PASSWORD}" stop; then
        echo "Server is shutting down gracefully..."
    else
        echo "Failed to send the stop command via rcon-cli, forcing the server to stop..."
        kill -TERM "$SERVER_PID" 2>/dev/null || true
    fi

    # Some mods leave non-daemon threads running after the server has saved
    # and stopped, keeping the JVM alive until Docker force-kills the whole
    # container. Wait a bounded time for a clean exit, then kill the JVM.
    for _ in $(seq 1 60); do
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            echo "Server stopped."
            exit 0
        fi
        sleep 1
    done

    echo "Server process still alive after 60s, sending KILL signal..."
    kill -KILL "$SERVER_PID" 2>/dev/null || true
    exit 0
}

copy_server_file() {
    local file_name=$1

    echo "Copying ${file_name} to /data..."
    cp "/tekxit-server/${file_name}" "/data/${file_name}"
}

contains_item() {
    local item=$1
    shift

    local list_item
    for list_item in "$@"; do
        if [ "${list_item}" = "${item}" ]; then
            return 0
        fi
    done

    return 1
}

sync_server_directory() {
    local dir_name=$1
    local config_defaults_dir

    mkdir -p "/data/${dir_name}"

    case "${dir_name}" in
        config)
            config_defaults_dir="/data/config-defaults/${IMAGE_VERSION:-unknown}"
            echo "Saving default config files to ${config_defaults_dir}..."
            rm -rf "${config_defaults_dir}"
            mkdir -p "${config_defaults_dir}"
            cp -R "/tekxit-server/${dir_name}" "${config_defaults_dir}/"

            echo "Adding new default config files without overwriting local config..."
            cp -Rn "/tekxit-server/${dir_name}/." "/data/${dir_name}/"
            ;;
        *)
            echo "Replacing ${dir_name} directory with server pack defaults..."
            rm -rf "/data/${dir_name}"
            cp -R "/tekxit-server/${dir_name}" "/data/"
            ;;
    esac
}

set_property() {
    local key=$1
    local value=$2
    local file=/data/server.properties
    local tmp_file

    tmp_file=$(mktemp)
    grep -v "^${key}=" "${file}" > "${tmp_file}" || true
    printf '%s=%s\n' "${key}" "${value}" >> "${tmp_file}"
    mv "${tmp_file}" "${file}"
}

# Set the trap for the TERM signal
trap 'shutdown_handler' TERM

# create data dir if it does not exist
if [ ! -d /data ]; then
    echo "creating missing /data dir"
    mkdir /data
fi

if [ -z "${RCON_PASSWORD:-}" ]; then
    echo "RCON_PASSWORD is required. Set it in your environment or .env file." >&2
    exit 1
fi

# Check for update indicator
IMAGE_VERSION=$(cat /tekxit-server/.tekxit-version 2>/dev/null || true)
DATA_VERSION=$(cat /data/.tekxit-version 2>/dev/null || true)

if [ -f /tekxit-server/update_indicator ] && [ "${IMAGE_VERSION}" != "${DATA_VERSION}" ]; then
    echo "Update indicator found, updating server from '${DATA_VERSION:-unknown}' to '${IMAGE_VERSION:-unknown}'..."
    # Remove the update indicator
    rm -f /tekxit-server/update_indicator

    # Files managed by the running server or local admin, not the image update.
    files_to_exclude=("server.properties" "eula.txt" "banned-ips.json" "banned-players.json" "ops.json" "usercache.json" "whitelist.json")
    dirs_to_exclude=("logs" "crash-reports" "world" "world_nether" "world_the_end")

    # Iterate over the files in /tekxit-server
    for item in /tekxit-server/*; do
        # If it's a file
        if [ -f "$item" ]; then
            # Extract the file name
            file_name=$(basename "$item")

            # If the file is not in the exclusion list
            if ! contains_item "${file_name}" "${files_to_exclude[@]}"; then
                copy_server_file "${file_name}"
            fi
        fi

        # If it's a directory
        if [ -d "$item" ]; then
            # Extract the directory name
            dir_name=$(basename "$item")

            if contains_item "${dir_name}" "${dirs_to_exclude[@]}"; then
                continue
            fi

            sync_server_directory "${dir_name}"
        fi
    done

    printf '%s\n' "${IMAGE_VERSION}" > /data/.tekxit-version
fi

# create eula.txt with EULA env variable if it does not exist
if [ ! -f /data/eula.txt ]; then
    echo "eula=${EULA:-false}" > /data/eula.txt
fi

# Check if server.properties exists
if [ ! -f /data/server.properties ]; then
    echo "server.properties not found, copying default configuration..."
    cp /tekxit-server/server.properties /data/server.properties
fi

# update server.properties with rcon configuration
set_property "enable-rcon" "true"
set_property "rcon.port" "${RCON_PORT:-$DEFAULT_RCON_PORT}"
set_property "rcon.password" "${RCON_PASSWORD}"

# fix ownership only where it's wrong; a full chown -R is slow on large worlds
find /data \( ! -user minecraft -o ! -group minecraft \) -exec chown minecraft:minecraft {} +

# Extract the line that contains the .jar item
jar_line=$(grep -m 1 -oP '[\w-]+\.jar' ServerLinux.sh || true)
if [ -z "${jar_line}" ]; then
    echo "Could not determine server jar from ServerLinux.sh" >&2
    exit 1
fi

echo "${jar_line}"

read -r -a java_additional_args <<< "${JAVA_ADDITIONAL_ARGS:-}"

gosu minecraft \
  java \
    -server \
    "-Xmx${JAVA_XMX}" \
    "-Xms${JAVA_XMS}" \
    "${java_additional_args[@]}" \
    -jar "${jar_line}" nogui \
    & SERVER_PID=$!

# Wait for the server to stop
wait "$SERVER_PID"
