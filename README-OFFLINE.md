# Operation Nightowl — Offline CTFd Handoff

This helper bundle is designed to be copied into the **root of the CTFd repository**
(the directory that already contains `docker-compose.yml`, `Dockerfile`, `CTFd/`, etc.).

It assumes the stack has already been tested online once and currently uses the
official CTFd Docker Compose project with CTFd + MariaDB + Redis + Nginx.

## What must be shared with teammates

Share **all of the following**:

1. The complete CTFd project folder, including:
   - `docker-compose.yml`
   - `Dockerfile`
   - `CTFd/`
   - `conf/`
   - all other files from the repository
2. `.ctfd_secret_key` if you want the copied instance to use the same CTFd secret.
   For a clean independent test instance, generate a new one instead.
3. `offline-images/nightowl-images.tar` created by `./export-offline.sh`
4. These helper scripts.

Do **not** share real admin passwords or unrelated credentials.

## Why the image archive is needed

`docker compose up` normally downloads or builds images.

An air-gapped/offline laptop cannot download:
- Nginx
- MariaDB
- Redis
- CTFd build dependencies

The export script saves the Docker images already used by the working stack into
one TAR file. The teammate loads the TAR before starting Compose.

## Connected machine — prepare the package

From the CTFd project directory:

```bash
chmod +x export-offline.sh load-offline.sh status.sh
./export-offline.sh
```

The important output is:

```text
offline-images/nightowl-images.tar
```

Then copy the **entire CTFd project folder** to a USB drive or other approved
offline transfer medium.

## Offline teammate — load and start

Docker Desktop / Docker Engine must already be installed.

From the copied CTFd directory:

```bash
chmod +x load-offline.sh status.sh
./load-offline.sh
```

Then open:

```text
http://localhost
```

Check status with:

```bash
./status.sh
```

## Stop the platform

```bash
docker compose -p ctfd down
```

This stops/removes the containers but keeps persistent named volumes.

## Start it again

```bash
docker compose -p ctfd up -d --no-build
```

## Important: do not use this unless you want to erase persistent data

```bash
docker compose -p ctfd down -v
```

`-v` removes Compose volumes. That can remove database state, users, scores,
challenge configuration, and other persistent data.

## Check logs

All services:

```bash
docker compose -p ctfd logs --tail=100
```

CTFd only:

```bash
docker compose -p ctfd logs --tail=100 ctfd
```

Follow live:

```bash
docker compose -p ctfd logs -f
```

## Architecture compatibility

Docker images are architecture-specific.

The original development machine is Apple Silicon (`arm64`). If the image TAR is
exported from an ARM64 Mac, it is safest to load it on another ARM64 system.

For Intel/AMD64 teammates, create a separate AMD64-compatible image bundle or use
a multi-architecture build. Do not assume an ARM64 image archive will run natively
on an AMD64 machine.

## Suggested folder layout

```text
CTFd/
├── docker-compose.yml
├── Dockerfile
├── CTFd/
├── conf/
├── .ctfd_secret_key
├── export-offline.sh
├── load-offline.sh
├── status.sh
└── offline-images/
    └── nightowl-images.tar
```

## Recommended team workflow

1. One machine is the "builder/exporter".
2. Test the full stack while connected.
3. Run `export-offline.sh`.
4. Copy the complete directory plus image TAR.
5. Teammates run `load-offline.sh`.
6. Test registration, a challenge submission, scoreboard updates, restart, and
   persistence while disconnected from the internet.
