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
FAILED=0
if [[ "${OUT}" != *"Hello from the mock LiteLLM of the sandbox-base test stack."* ]]; then
    echo "FAIL: OpenCode in the SSH session did not answer through LiteLLM"
    docker compose -f "$COMPOSE" logs litellm 2>&1 | tail -40
    FAILED=1
fi
# with the gateway, OpenCode offers the models of LiteLLM alone, none of its own
# such as those of OpenCode Zen, whose calls would leave the sandbox directly
# (a line of the list is <provider>/<model>; other lines, such as a notice of
# OpenCode, are no model)
MODELS=$(grep -E "^MODEL [^ /]+/[^ ]+$" <<< "${OUT}")
if ! grep -qx "MODEL litellm/test-model" <<< "${MODELS}"; then
    echo "FAIL: opencode models does not list litellm/test-model"
    echo "${MODELS}"
    FAILED=1
fi
if [[ -n "${MODELS}" ]] && grep -v "^MODEL litellm/" <<< "${MODELS}"; then
    echo "FAIL: opencode models lists models of other providers than LiteLLM (above)"
    FAILED=1
fi
[[ ${FAILED} -eq 0 ]] || exit 1
echo "==> E2E passed"
