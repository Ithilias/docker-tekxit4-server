# docker-tekxit4-server

Docker image to run a Minecraft [Tekxit 4](https://www.technicpack.net/modpack/tekxit-4-official.1921233) server.

- Multi-arch images (`linux/amd64`, `linux/arm64`) published to GitHub Container Registry, tracking new Tekxit releases automatically.
- Automatic server-pack updates on image update, preserving your local configuration, world, and runtime files.
- Graceful shutdown: `docker stop` saves the world via RCON before the container exits.
- Runs the server as a non-root user, with a built-in healthcheck and [rcon-cli](https://github.com/itzg/rcon-cli) preinstalled.

Running the server means you accept the [Minecraft EULA](https://aka.ms/MinecraftEULA).

## Quick start (pre-built image)

Images are published to `ghcr.io/ithilias/docker-tekxit4-server`. Use the `latest` tag to follow Tekxit releases, or pin a version tag (e.g. `16.8.8`) for controlled upgrades.

Create a `docker-compose.yml`:

```yaml
services:
  tekxit:
    container_name: tekxit
    image: ghcr.io/ithilias/docker-tekxit4-server:latest
    restart: unless-stopped
    stop_grace_period: 2m
    environment:
      JAVA_XMS: 4G
      JAVA_XMX: 12G
      JAVA_ADDITIONAL_ARGS: "-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true"
      EULA: true
      RCON_PORT: 25575
      RCON_PASSWORD: ${RCON_PASSWORD:?Set RCON_PASSWORD in your environment or .env file}
    ports:
      - "25565:25565"
      - "24454:24454/udp"
    volumes:
      - ./data:/data
```

Set the RCON password and start the server:

```sh
echo "RCON_PASSWORD=change-me" > .env
docker compose up -d
```

All server state is written to `./data`. Adjust `JAVA_XMS`/`JAVA_XMX` to your hardware; leave a few GB of headroom above `JAVA_XMX` for the JVM itself and the OS.

The first start generates the world and can take several minutes. The built-in healthcheck allows up to 10 minutes before the container is considered unhealthy; check progress with `docker compose logs -f` or the health column of `docker ps`.

## Building from source

The repository ships the same Compose setup with a `build` section instead of an `image`:

```sh
git clone https://github.com/Ithilias/docker-tekxit4-server.git
cd docker-tekxit4-server

cp .env.example .env
# Replace RCON_PASSWORD in .env before starting the server.

docker compose up -d
```

The provided Compose file sets `EULA=true`. Only run the server if you accept the [Minecraft EULA](https://aka.ms/MinecraftEULA).

## Updates

New Tekxit releases are detected daily; the resulting image is boot-tested in CI before it is published to the registry.

When the image updates, server-pack files are refreshed in the data volume. Existing files in `/data/config` are preserved so local configuration changes are not overwritten; new default config files are added when present.

Default config files from each image version are saved under `/data/config-defaults/<version>/config` so you can compare upstream config changes with your local `/data/config` files.

Runtime-managed files are not overwritten during image updates, including `server.properties`, `eula.txt`, ban lists, ops, whitelist, logs, crash reports, and world directories.

## Configuration

Useful environment variables:

| Variable | Default | Description |
| --- | --- | --- |
| `JAVA_XMS` | `1G` | Initial Java heap size. |
| `JAVA_XMX` | `4G` | Maximum Java heap size. |
| `JAVA_ADDITIONAL_ARGS` | empty | Additional JVM arguments. |
| `EULA` | `false` | Writes `eula.txt` on first start. Set to `true` only if you accept the Minecraft EULA. |
| `RCON_PORT` | `25575` | RCON port inside the container. |
| `RCON_PASSWORD` | required | RCON password. Set this in `.env` or your environment. |

Ports:

| Port | Protocol | Purpose |
| --- | --- | --- |
| `25565` | TCP | Minecraft |
| `24454` | UDP | Simple Voice Chat |
| `25575` | TCP | RCON. Intentionally not published in the Compose file; do not expose it publicly. |

## Accessing the console

RCON is enabled automatically using the `RCON_PORT` and `RCON_PASSWORD` environment variables. To access the console, use the `mc-command.sh` script:

```sh
./mc-command.sh -h
```

The helper defaults to the Compose service name `tekxit`. If your Compose file uses a different service name, set `MC_SERVICE` or pass `--service`:

```sh
MC_SERVICE=minecraft ./mc-command.sh "list"
./mc-command.sh --service minecraft "list"
```

Run a command directly:

```sh
./mc-command.sh "list"
```

Or start interactive mode:

```sh
./mc-command.sh
```

## Shutdown and backups

`docker stop` (and `docker compose down`) triggers a clean shutdown: the entrypoint sends the `stop` command via RCON, the server saves the world, and the container exits once the JVM has finished (some mods leave threads running after shutdown; these are cleaned up automatically after 60 seconds). If you write your own Compose file, keep `stop_grace_period` at 90 seconds or more so Docker does not kill the server mid-save.

All server state lives in the `./data` volume. For consistent backups, stop the server first, then copy or snapshot the directory.
