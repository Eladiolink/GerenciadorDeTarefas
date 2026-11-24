# Imagem compartilhada do modo de desenvolvimento.
# Roda Maven com o UID/GID do usuario do host para evitar arquivos root em target/.
FROM maven:3.10.0-eclipse-temurin-25-noble

ARG UID=1000
ARG GID=1000

# inotify-tools detecta saves no bind mount e dispara a recompilacao.
RUN apt-get update \
    && apt-get install -y --no-install-recommends inotify-tools \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${GID}" dev 2>/dev/null || true \
    && useradd --uid "${UID}" --gid "${GID}" --create-home --shell /bin/bash dev 2>/dev/null || true \
    && mkdir -p /home/dev/.m2 \
    && chown -R "${UID}:${GID}" /home/dev

ENV HOME=/home/dev \
    MAVEN_CONFIG=/home/dev/.m2

COPY docker/dev/dev-run.sh /usr/local/bin/dev-run.sh
RUN chmod +x /usr/local/bin/dev-run.sh

USER ${UID}:${GID}

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/dev-run.sh"]
