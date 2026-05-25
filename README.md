# docker-tekxit4-server

Dockerfiles to run a Minecraft [tekxit4](https://www.technicpack.net/modpack/tekxit-4-official.1921233) server.

## Usage

### Setting up the server

```sh
git clone https://github.com/Ithilias/docker-tekxit4-server.git
cd docker-tekxit4-server

# Server data is written to ./data by default. Change the volume before first start if you want another location.
# Memory limits can be changed with JAVA_XMS and JAVA_XMX in docker-compose.yml.

cp .env.example .env
# Replace RCON_PASSWORD in .env before starting the server.

docker compose up
```

The provided Compose file sets `EULA=true`. Only run the server if you accept the [Minecraft EULA](https://aka.ms/MinecraftEULA).

Alternatively, you can use the Docker image available as a package on GitHub.
Here's an example `docker-compose.yml` file for using the Docker image:

```yaml
services:
  tekxit:
    container_name: tekxit
    image: ghcr.io/ithilias/docker-tekxit4-server:latest
    environment:
      JAVA_XMS: "4G"
      JAVA_XMX: "12G"
      EULA: "true"
      RCON_PORT: "25575"
      RCON_PASSWORD: ${RCON_PASSWORD:?Set RCON_PASSWORD in your environment or .env file}
    volumes:
      - ./data:/data
    ports:
      - "25565:25565"
      - "24454:24454/udp"
```

The server will now be installed to the data volume.

### Updates

When the image updates, server-pack files are refreshed in the data volume. Existing files in `/data/config` are preserved so local configuration changes are not overwritten; new default config files are added when present.

Default config files from each image version are saved under `/data/config-defaults/<version>/config` so you can compare upstream config changes with your local `/data/config` files.

Runtime-managed files are not overwritten during image updates, including `server.properties`, `eula.txt`, ban lists, ops, whitelist, logs, crash reports, and world directories.

### Configuration

Useful environment variables:

| Variable | Default | Description |
| --- | --- | --- |
| `JAVA_XMS` | `1G` | Initial Java heap size. |
| `JAVA_XMX` | `4G` | Maximum Java heap size. |
| `JAVA_ADDITIONAL_ARGS` | empty | Additional JVM arguments. |
| `EULA` | `false` | Writes `eula.txt` on first start. Set to `true` only if you accept the Minecraft EULA. |
| `RCON_PORT` | `25575` | RCON port inside the container. |
| `RCON_PASSWORD` | required | RCON password. Set this in `.env` or your environment. |

The server exposes Minecraft on TCP `25565` and Simple Voice Chat on UDP `24454`.

### Accessing the console

This image comes with [rcon-cli](https://github.com/itzg/rcon-cli) preinstalled. The RCON port and password can be configured using the `RCON_PORT` and `RCON_PASSWORD` environment variables in the docker-compose file.

To access the console, you can use the `mc-command.sh` script:

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
