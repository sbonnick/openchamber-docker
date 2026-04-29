# syntax=docker/dockerfile:1
FROM node:lts-slim AS openchamber-base

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && rm -rf /var/lib/apt/lists/*

RUN groupmod -n openchamber node \
  && usermod -l openchamber -d /home/openchamber -m node \
  && install -d -o openchamber -g openchamber /home/openchamber/workspace

ENV BUN_INSTALL=/home/openchamber/.bun \
    HOME=/home/openchamber \
    NODE_ENV=production \
    PATH=/home/openchamber/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /home/openchamber/workspace

FROM openchamber-base AS openchamber-web

ARG OPENCHAMBER_VERSION=1.9.9
ARG OPENCODE_VERSION=1.14.28
ARG BUN_VERSION=1.3.13

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential python3 unzip \
  && rm -rf /var/lib/apt/lists/*

USER openchamber

RUN curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}" \
  && bun install -g "@openchamber/web@${OPENCHAMBER_VERSION}" "opencode-ai@${OPENCODE_VERSION}" \
  && rm -rf /home/openchamber/.bun/install/cache /home/openchamber/.cache/node-gyp

FROM openchamber-base

RUN apt-get update \
  && apt-get install -y --no-install-recommends git gosu openssh-client \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*

ENV OPENCHAMBER_HOST=0.0.0.0 \
    OPENCHAMBER_PORT=3000

COPY --from=openchamber-web --chown=openchamber:openchamber /home/openchamber/.bun /home/openchamber/.bun
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/openchamber-entrypoint

EXPOSE 3000
ENTRYPOINT ["openchamber-entrypoint"]
