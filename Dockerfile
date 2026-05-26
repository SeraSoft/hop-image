# =============================================================================
# STAGE 1: BUILD HOP
# =============================================================================
FROM eclipse-temurin:21-jdk-jammy AS hop-builder

ARG HOP_REPO=https://github.com/SeraSoft/hop.git
ARG HOP_BRANCH=main

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        maven \
        unzip \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 --branch ${HOP_BRANCH} ${HOP_REPO} hop

WORKDIR /build/hop

# Build sequenziale (no -T 4): evita race condition nei moduli assembly.
# Il modulo assemblies/static produce lo zip con tutti i binari.
RUN mvn -q -DskipTests=true clean install

# Estrai lo zip: contiene una cartella radice "hop/" con lib, plugins ecc.
RUN mkdir -p /opt/hop-dist && \
    unzip -q assemblies/static/target/hop-assemblies-static-*.zip -d /opt/hop-dist-raw && \
    mv /opt/hop-dist-raw/hop/* /opt/hop-dist/ && \
    rm -rf /opt/hop-dist-raw

# =============================================================================
# STAGE 2: RUNTIME
# =============================================================================
FROM alpine:3 AS runtime

ARG HOP_VERSION=2.16.2
ARG HOP_UID=501
ARG HOP_GID=501

LABEL maintainer="SeraSoft"
LABEL org.opencontainers.image.source="https://github.com/SeraSoft/hop"
LABEL org.opencontainers.image.description="Apache Hop built from the SeraSoft fork"

ENV DEPLOYMENT_PATH=/opt/hop
ENV VOLUME_MOUNT_POINT=/files

ENV HOP_OPTIONS="-Xmx2048m"
ENV HOP_RUN_CONFIG=""
ENV HOP_RUN_PARAMETERS=""
ENV HOP_FILE_PATH=""
ENV HOP_LOG_LEVEL="Basic"
ENV HOP_PROJECT_NAME=""
ENV HOP_PROJECT_DIRECTORY=""
ENV HOP_ENVIRONMENT_NAME=""
ENV HOP_ENVIRONMENT_CONFIG_FILES_FOLDER_PATH=""
ENV HOP_SERVER_USER="cluster"
ENV HOP_SERVER_PASSWORD="cluster"
ENV HOP_SERVER_PORT="8080"
ENV HOP_SERVER_SHUTDOWNPORT="8079"
ENV HOP_SHARED_JDBC_FOLDERS=""

RUN addgroup -g ${HOP_GID} -S hop \
    && adduser -u ${HOP_UID} -S -G hop hop \
    && apk add --no-cache \
        bash \
        openjdk21-jre \
        fontconfig \
        ttf-dejavu \
    && fc-cache -f \
    && rm -rf /var/cache/apk/* \
    && mkdir ${DEPLOYMENT_PATH} \
    && mkdir ${VOLUME_MOUNT_POINT} \
    && chown hop:hop ${DEPLOYMENT_PATH} \
    && chown hop:hop ${VOLUME_MOUNT_POINT}

COPY --from=hop-builder --chown=hop:hop /opt/hop-dist/                                    ${DEPLOYMENT_PATH}/
COPY --from=hop-builder --chown=hop:hop /build/hop/docker/resources/run.sh                ${DEPLOYMENT_PATH}/run.sh
COPY --from=hop-builder --chown=hop:hop /build/hop/docker/resources/load-and-execute.sh  ${DEPLOYMENT_PATH}/load-and-execute.sh

EXPOSE 8080 8079

VOLUME ["/files"]

USER hop
ENV PATH=$PATH:${DEPLOYMENT_PATH}
WORKDIR /home/hop

ENTRYPOINT ["/bin/bash", "/opt/hop/run.sh"]
