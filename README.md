# hop-image

Public Docker image for [Apache Hop](https://hop.apache.org/) built from the [SeraSoft fork](https://github.com/SeraSoft/hop). The image is automatically compiled from source and published to the GitHub Container Registry via a manually triggered GitHub Actions workflow.

## Published image

```
ghcr.io/serasoft/hop-image:latest
ghcr.io/serasoft/hop-image:<version>   # e.g. ghcr.io/serasoft/hop-image:2.16.2
```

## How it works

A GitHub Actions workflow builds and pushes the image on every push to `main`. It can also be triggered manually from the Actions tab, optionally specifying a target Hop version.

If no version is specified, the workflow resolves the latest stable release tag (format `X.Y.Z`) from the SeraSoft Hop fork automatically.

The image is built using a two-stage Dockerfile:

- **hop-builder** — clones and compiles the SeraSoft fork using Maven and JDK 17.
- **runtime** — Alpine-based final image with only the Hop binaries and the official entrypoint scripts.

Build layers are cached via GitHub Actions cache (`type=gha`) to speed up subsequent builds.

## Triggering a build manually

Go to **Actions → Build and publish Docker image → Run workflow**.

You can optionally enter a specific version (e.g. `2.16.2`). Leave the field empty to build the latest stable release.

## Running the image

### Run a pipeline or workflow

```bash
docker run --rm \
  -v /path/to/your/project:/files \
  -e HOP_FILE_PATH=/files/main.hwf \
  -e HOP_PROJECT_NAME=myproject \
  -e HOP_PROJECT_DIRECTORY=/files \
  -e HOP_ENVIRONMENT_NAME=dev \
  -e HOP_RUN_CONFIG=local \
  ghcr.io/serasoft/hop-image:latest
```

### Start Hop Server

When `HOP_FILE_PATH` is not set, the container starts Hop Server on port 8080:

```bash
docker run -d \
  --name hop-server \
  -p 8080:8080 \
  -e HOP_SERVER_USER=cluster \
  -e HOP_SERVER_PASSWORD=cluster \
  ghcr.io/serasoft/hop-image:latest
```

### Verify binaries

```bash
docker run --rm --entrypoint /bin/bash ghcr.io/serasoft/hop-image:latest -c "/opt/hop/hop-run.sh --version"
```

## Environment variables

| Variable                                      | Default     | Description                                              |
|-----------------------------------------------|-------------|----------------------------------------------------------|
| `HOP_OPTIONS`                                 | `-Xmx2048m` | JVM options                                              |
| `HOP_FILE_PATH`                               |             | Path to the pipeline or workflow file to execute         |
| `HOP_LOG_LEVEL`                               | `Basic`     | Log level (None, Error, Minimal, Basic, Detailed, Debug) |
| `HOP_RUN_CONFIG`                              |             | Run configuration name                                   |
| `HOP_RUN_PARAMETERS`                          |             | Pipeline/workflow parameters (`PARAM=value,...`)         |
| `HOP_PROJECT_NAME`                            |             | Hop project name                                         |
| `HOP_PROJECT_DIRECTORY`                       |             | Hop project directory                                    |
| `HOP_ENVIRONMENT_NAME`                        |             | Hop environment name                                     |
| `HOP_ENVIRONMENT_CONFIG_FILES_FOLDER_PATH`    |             | Path to environment config files folder                  |
| `HOP_SERVER_USER`                             | `cluster`   | Hop Server username                                      |
| `HOP_SERVER_PASSWORD`                         | `cluster`   | Hop Server password                                      |
| `HOP_SERVER_PORT`                             | `8080`      | Hop Server HTTP port                                     |
| `HOP_SERVER_SHUTDOWNPORT`                     | `8079`      | Hop Server shutdown port                                 |
| `HOP_SHARED_JDBC_FOLDERS`                     |             | Path(s) to shared JDBC driver folders                    |

## Building locally

```bash
./build.sh
```

Or for a specific version:

```bash
HOP_VERSION=2.16.2 ./build.sh
```

## Security notes

- No credentials are required to build this image — the SeraSoft Hop fork is public.
- The runtime image runs as a non-root user (`hop`, UID 501).
- The default Hop Server credentials (`cluster` / `cluster`) should be changed in production.
