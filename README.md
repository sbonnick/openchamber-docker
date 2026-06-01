# OpenChamber + OpenCode Docker

This builds a small local image for the OpenChamber web UI on the latest Node LTS slim base, installs Bun directly during the OpenChamber build, and installs OpenCode with Bun.

## Run

```bash
copy .env.example .env
docker compose -f docker-compose.build.yml build
docker compose up -d
```

Open `http://localhost:6123`, or `http://localhost:3000` if you copied `.env.example` to `.env`.

Set `OPENCHAMBER_UI_PASSWORD` in `.env` to password-protect the browser UI.

## Compose Files

- `docker-compose.build.yml` builds the image locally.
- `docker-compose.yml` deploys a prebuilt image.

## Publishing

`.github/workflows/publish-image.yml` publishes the image to GHCR on pushes to `main`, version tags, and manual workflow runs. Update `IMAGE_NAME` in that workflow when the real repository/package name is final.

## Image Notes

The OpenChamber image uses `node:lts-slim` for both build and runtime stages. Build-only packages are kept in the build stage while the runtime stage receives the Bun-installed OpenChamber package, the directly installed Bun runtime, and the Bun-installed OpenCode package. OpenChamber starts that local OpenCode binary inside the same container.

## Persistent Data

The Compose file persists runtime data under `./data`:

- `data/openchamber` for OpenChamber settings
- `data/opencode/config` for OpenCode config
- `data/opencode/share` for OpenCode local share data and logs
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
```
