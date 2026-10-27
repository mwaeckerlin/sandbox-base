#!/usr/bin/env bash
# Run the sandbox-base e2e suite: start the sandbox with a running sshd,
# then log in through SSH with a freshly generated key and execute the
# toolchain exactly like a sandbox user would; then OpenCode in that session
# answers a prompt through a real LiteLLM with a mock model.
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

echo "==> Starting sandbox and LiteLLM..."
docker compose -f "$COMPOSE" up -d sandbox litellm

echo "==> Running SSH e2e..."
OUT=$(docker compose -f "$COMPOSE" run --rm runner 2>&1)
EXIT=$?
echo "${OUT}"
if [[ ${EXIT} -ne 0 || "${OUT}" != *"SSH-E2E-OK"* ]]; then
    echo "FAIL: SSH e2e did not complete"
    docker compose -f "$COMPOSE" ps -a
    docker compose -f "$COMPOSE" logs --tail 40 sandbox
    docker compose -f "$COMPOSE" logs --tail 30 litellm
    exit 1
fi
if [[ "${OUT}" != *"Hello from the mock LiteLLM of the sandbox-base test stack."* ]]; then
    echo "FAIL: OpenCode in the SSH session did not answer through LiteLLM"
    docker compose -f "$COMPOSE" logs litellm 2>&1 | tail -40
    exit 1
fi
echo "==> E2E passed"
