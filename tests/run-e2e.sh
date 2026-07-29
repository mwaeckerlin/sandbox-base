#!/usr/bin/env bash
# Run the sandbox-base e2e suite: start the sandbox with a running sshd,
# then log in through SSH with a freshly generated key and execute the
# toolchain exactly like a sandbox user would.
# Usage: bash tests/run-e2e.sh
set -uo pipefail

COMPOSE="tests/e2e/docker-compose.yml"
cd "$(dirname "$0")/.."

cleanup() {
    docker compose -f "$COMPOSE" down -v --remove-orphans 2>/dev/null || true
}
trap cleanup EXIT

echo "==> Building test stack..."
docker compose -f "$COMPOSE" build --quiet

echo "==> Starting sandbox..."
docker compose -f "$COMPOSE" up -d sandbox

echo "==> Running SSH e2e..."
OUT=$(docker compose -f "$COMPOSE" run --rm runner 2>&1)
EXIT=$?
echo "${OUT}"
if [[ ${EXIT} -ne 0 || "${OUT}" != *"SSH-E2E-OK"* ]]; then
    echo "FAIL: SSH e2e did not complete"
    docker compose -f "$COMPOSE" logs sandbox 2>&1 | tail -40
    exit 1
fi
echo "==> E2E passed"
