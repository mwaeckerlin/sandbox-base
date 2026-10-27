#!/usr/bin/env bash
# Config contract: the shared sandbox base must ship the full toolset, the
# hardened SSH configuration and the docker client the derived sandboxes
# (hermes, openclaw) rely on. `--pull=never` keeps docker from silently
# pulling a stale image when the local build is missing.
#
# Usage: tests/config-contract.sh IMAGE

set -uo pipefail

IMAGE="${1:?usage: tests/config-contract.sh IMAGE}"

PASS=0
FAIL=0
declare -a FAILED_NAMES

_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
_fail() { FAIL=$((FAIL + 1)); FAILED_NAMES+=("$1"); echo "  FAIL  $1: $2"; }

_check() {
    local name="$1" cmd="$2" msg="$3"
    if docker run --rm --pull=never --entrypoint /bin/bash "${IMAGE}" -c "${cmd}" > /dev/null 2>&1; then
        _pass "${IMAGE}_${name}"
    else
        _fail "${IMAGE}_${name}" "${msg}"
    fi
}

echo "==> Config contract: shared SSH sandbox base"

if ! docker image inspect "${IMAGE}" > /dev/null 2>&1; then
    _fail "${IMAGE}_image_exists" "image not built — run 'npm run build' first"
else
    # one spot check per package set (F1)
    _check tools_dev      'gcc --version && git --version'      "dev toolchain missing"
    _check tools_lang     'python3 --version && node --version' "language runtimes missing"
    _check tools_media    'convert --version && ffmpeg -version' "media tools missing"
    _check tools_latex    'pdflatex --version'                  "latex missing"
    _check tools_utils    'jq --version && rsync --version'     "utilities missing"
    _check tools_db       'psql --version && sqlite3 --version' "database clients missing"
    _check inventory_file 'test -s /etc/installed-ubuntu-packages' "package inventory missing"

    # hardened sshd (F2) — the directives must be effective, not just present
    _check sshd_present   'test -x /usr/sbin/sshd'              "sshd missing"
    _check sshd_no_password 'grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config' "password auth not disabled"
    _check sshd_no_root   'grep -q "^PermitRootLogin no" /etc/ssh/sshd_config' "root login not disabled"
    _check sshd_pubkey    'grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config' "pubkey auth not enabled"
    _check ssh_dir        'test "$(stat -c "%a %U" /home/somebody/.ssh)" = "700 somebody"' "~/.ssh not prepared (700, somebody)"

    # docker client (F3)
    _check docker_client  'docker --version'                    "docker client missing"
    _check compose_plugin 'docker compose version'              "compose plugin missing"
    _check docker_group   'id -nG somebody | grep -qw docker'   "runtime user not in docker group"

    # OpenCode (F6): the binary of the build's architecture behind the wrapper,
    # which writes the configuration from the environment and puts no key in it
    _check opencode_runs  'opencode --version'                  "opencode missing or not runnable"
    _check opencode_no_update 'test "${OPENCODE_DISABLE_AUTOUPDATE}" = true && test "${OPENCODE_DISABLE_MODELS_FETCH}" = true' "automatic update or model download not switched off"
    _check opencode_config_through_gateway \
        'c=$(OPENCODE_GATEWAY_URL=http://gw:8080 OPENCODE_MODELS="m1, m2" HINDSIGHT_SHARED_BANK=shared HINDSIGHT_OWN_BANK=agent opencode --print-config)
         test "$(jq -r .provider.litellm.options.baseURL <<< "$c")" = http://gw:8080/v1 &&
         test "$(jq -r .model <<< "$c")" = litellm/m1 &&
         test "$(jq -r ".provider.litellm.models | keys | join(\",\")" <<< "$c")" = m1,m2 &&
         test "$(jq -r ".mcp[\"hindsight-shared\"].url" <<< "$c")" = http://gw:8080/mcp/shared/ &&
         test "$(jq -r ".mcp[\"hindsight-own\"].url" <<< "$c")" = http://gw:8080/mcp/agent/ &&
         test "$(jq -r .provider.litellm.options.apiKey <<< "$c")" = the-gateway-replaces-this' \
        "configuration from the environment is wrong"
    _check opencode_small_model \
        'c=$(OPENCODE_GATEWAY_URL=http://gw:8080 OPENCODE_MODELS="m1, m2" OPENCODE_SMALL_MODEL=" s1 " opencode --print-config)
         test "$(jq -r .small_model <<< "$c")" = litellm/s1 &&
         test "$(jq -r ".provider.litellm.models | keys | join(\",\")" <<< "$c")" = m1,m2,s1 &&
         test "$(jq -r .model <<< "$c")" = litellm/m1' \
        "the small model is not configured"
    _check opencode_no_small_model_by_default \
        'test "$(OPENCODE_GATEWAY_URL=http://gw:8080 OPENCODE_MODELS=m1 opencode --print-config | jq -r "has(\"small_model\")")" = false' \
        "a small model is configured although none is named"
    _check opencode_no_memory_without_banks \
        'test "$(OPENCODE_GATEWAY_URL=http://gw:8080 opencode --print-config | jq -c .mcp)" = "{}"' \
        "memory banks configured although none is named"
    _check opencode_without_gateway_own_config \
        'test -z "$(env -u OPENCODE_GATEWAY_URL opencode --print-config)"' \
        "a configuration is written without a gateway"
    _check opencode_invalid_bank_refused \
        '! OPENCODE_GATEWAY_URL=http://gw:8080 HINDSIGHT_OWN_BANK=../v1 opencode --print-config && OPENCODE_GATEWAY_URL=http://gw:8080 HINDSIGHT_OWN_BANK=../v1 opencode --print-config 2>&1 | grep -q "invalid bank id"' \
        "a bank id that changes the MCP path is accepted"
    _check opencode_invalid_gateway_refused \
        '! OPENCODE_GATEWAY_URL="file:///etc" opencode --print-config' \
        "a gateway that is no http address is accepted"

    # drop-in base (F4)
    _check environment_file 'test "$(stat -c "%a %U" /etc/environment)" = "700 somebody"' "/etc/environment not prepared"
    PORTS=$(docker image inspect --format '{{.Config.ExposedPorts}}' "${IMAGE}" 2>&1)
    if echo "${PORTS}" | grep -q '22/tcp'; then
        _pass "${IMAGE}_port_22_exposed"
    else
        _fail "${IMAGE}_port_22_exposed" "port 22 not exposed: ${PORTS}"
    fi
    HC=$(docker image inspect --format '{{.Config.Healthcheck.Test}}' "${IMAGE}" 2>&1)
    if echo "${HC}" | grep -q 'nc -z localhost 22'; then
        _pass "${IMAGE}_healthcheck_defined"
    else
        _fail "${IMAGE}_healthcheck_defined" "healthcheck missing: ${HC}"
    fi
fi

echo ""
echo "==> Config contract results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -gt 0 ]]; then
    echo "==> Failed contracts: ${FAILED_NAMES[*]}"
    exit 1
fi
