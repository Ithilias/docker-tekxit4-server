#!/bin/bash
set -euo pipefail

# Default values
RCON_PASSWORD=${RCON_PASSWORD:-}
RCON_PORT=${RCON_PORT:-25575}
MC_SERVICE=${MC_SERVICE:-tekxit}
COMMAND=()

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo ""
    echo "Options:"
    echo "  --password, -p   Specify the RCON password (default: RCON_PASSWORD env var)"
    echo "  --port, -P       Specify the RCON port (default: $RCON_PORT)"
    echo "  --service, -s    Specify the Compose service name (default: $MC_SERVICE)"
    echo "  --help, -h       Show this help message"
    echo ""
    echo "If no COMMAND is specified, the script will run in interactive mode."
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --password|-p)
            if [[ $# -lt 2 ]]; then
                echo "Missing value for $1" >&2
                exit 1
            fi
            RCON_PASSWORD="$2"
            shift
            ;;
        --port|-P)
            if [[ $# -lt 2 ]]; then
                echo "Missing value for $1" >&2
                exit 1
            fi
            RCON_PORT="$2"
            shift
            ;;
        --service|-s)
            if [[ $# -lt 2 ]]; then
                echo "Missing value for $1" >&2
                exit 1
            fi
            MC_SERVICE="$2"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            COMMAND+=("$1")
            ;;
    esac
    shift
done

if [ -z "${RCON_PASSWORD}" ]; then
    echo "RCON password is required. Set RCON_PASSWORD or pass --password." >&2
    exit 1
fi

if ! docker compose ps --services --filter status=running | grep -Fxq "${MC_SERVICE}"; then
    echo "Compose service '${MC_SERVICE}' is not running or does not exist." >&2
    echo "Set MC_SERVICE or pass --service if your server service is not named 'tekxit'." >&2
    exit 1
fi

# Run the rcon-cli command
docker compose exec "${MC_SERVICE}" rcon-cli --host localhost --port "${RCON_PORT}" --password "${RCON_PASSWORD}" "${COMMAND[@]}"
