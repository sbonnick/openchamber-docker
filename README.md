# OpenChamber + OpenCode Docker

This builds a small local image for the OpenChamber web UI on the latest Node LTS base, installs Bun directly during the OpenChamber build, installs OpenCode with npm, and ships a browser-accessible terminal (ttyd + tmux) on the port one above OpenChamber.

## Run

```bash
cp .env.example .env
docker compose -f docker-compose.build.yml build
docker compose up -d
```

Open `http://localhost:5173` for the OpenChamber UI and `http://localhost:5174/terminal` for the browser terminal. Override the host ports with `OPENCHAMBER_PORT` and `TTYD_PORT` in `.env` (keep `TTYD_PORT` one above `OPENCHAMBER_PORT`).

Set `OPENCHAMBER_UI_PASSWORD` in `.env` to password-protect both the browser UI and the terminal (HTTP Basic auth on ttyd).


## Compose Files

- `docker-compose.build.yml` builds the image locally.
- `docker-compose.yml` deploys a prebuilt image.

## Publishing

`.github/workflows/publish-image.yml` publishes the image to GHCR on pushes to `main`, version tags, and manual workflow runs. Update `IMAGE_NAME` in that workflow when the real repository/package name is final.

## Image Notes

The OpenChamber image uses `oven/bun:1` for both build and runtime stages. Build-only packages are kept in the build stage while the runtime stage receives the Bun-installed OpenChamber package, the npm-installed OpenCode binary, the Node.js runtime (pinned via `NODE_VERSION` in the Dockerfile), the GitHub CLI, and `ttyd` + `tmux` for the browser terminal. The image `EXPOSE`s `5173` (OpenChamber web UI) and `5174` (ttyd)

## Browser Terminal

The container ships a ttyd instance wrapping a persistent tmux session named `openchamber`. The tmux server keeps running in the background, so the session survives browser disconnects and you can reconnect to the same workspace from any browser. ttyd binds to in-container port `5174` (declared by `EXPOSE 5174` in the `Dockerfile`; overridable via the `TTYD_LISTEN_PORT` env var) and is launched by `docker-entrypoint.sh` as `ttyd -p ${TTYD_LISTEN_PORT:-5174} -b /terminal tmux new-session -A -s openchamber`. The `-b /terminal` flag means the terminal is served at the URL path `/terminal` (e.g. `http://localhost:5174/terminal`). If `UI_PASSWORD` is set, ttyd enforces HTTP Basic auth with username `openchamber`. The host port is controlled by `TTYD_PORT` in `.env` and defaults to one above `OPENCHAMBER_PORT`.

## Persistent Data

The Compose file persists runtime data under `./data`:

- `data/openchamber` for OpenChamber settings
- `data/opencode/config` for OpenCode config
- `data/opencode/share` for OpenCode local share data and logs (including `log/ttyd.log`)
- `data/opencode/state` for OpenCode runtime state
- `data/ssh` for the generated SSH key
- `data/workspace` for project files

On Linux, if the container cannot write to `./data`, run:

```bash
mkdir -p data/openchamber data/opencode/config data/opencode/share data/opencode/state data/ssh data/workspace
sudo chown -R 1000:1000 data
```

## Useful Commands

```bash
docker compose logs -f openchamber
docker compose exec openchamber bun --version
docker compose exec openchamber openchamber --help
docker compose exec openchamber opencode --version
docker compose exec openchamber tmux attach -t openchamber
docker compose exec openchamber ttyd --version
```
