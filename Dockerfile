# syntax=docker/dockerfile:1
FROM oven/bun:1 AS base
WORKDIR /app

FROM base AS deps

ARG OPENCHAMBER_VERSION=1.12.0

ENV BUN_INSTALL=/opt/bun \
    PATH=/opt/bun/bin:${PATH}

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  python3 \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "${BUN_INSTALL}" \
  && bun install -g "@openchamber/web@${OPENCHAMBER_VERSION}" \
  && rm -rf "${BUN_INSTALL}/install/cache" /root/.cache/node-gyp

FROM oven/bun:1 AS runtime
WORKDIR /home/openchamber

ARG OPENCODE_VERSION=1.15.13
ARG NODE_VERSION=22

RUN ln -s /bin/bash /bash

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  && curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
  && apt-get install -y --no-install-recommends \
  bash \
  git \
  gosu \
  less \
  nodejs \
  openssh-client \
  python3 \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*

# Replace the base image's 'bun' user (UID 1000) with 'openchamber'
# so mounted volumes with 1000:1000 ownership work correctly.
RUN userdel bun \
  && groupadd -g 1000 openchamber \
  && useradd -u 1000 -g 1000 -m -s /bin/bash openchamber \
  && chown -R openchamber:openchamber /home/openchamber

USER openchamber

ENV NODE_ENV=production \
    NPM_CONFIG_PREFIX=/home/openchamber/.npm-global \
    PATH=/home/openchamber/.npm-global/bin:${PATH}

RUN npm config set prefix /home/openchamber/.npm-global && mkdir -p /home/openchamber/.npm-global && \
  mkdir -p /home/openchamber/.local /home/openchamber/.config /home/openchamber/.ssh /home/openchamber/workspace /home/openchamber/packages && \
  npm install -g "opencode-ai@${OPENCODE_VERSION}"

USER root

COPY --chmod=0755 docker-entrypoint.sh /home/openchamber/openchamber-entrypoint.sh
COPY --from=deps --chown=openchamber:openchamber /opt/bun/install/global/node_modules /home/openchamber/node_modules
COPY --from=deps --chown=openchamber:openchamber /opt/bun/install/global/node_modules/@openchamber/web /home/openchamber/packages/web

EXPOSE 3000

ENTRYPOINT ["sh", "/home/openchamber/openchamber-entrypoint.sh"]
