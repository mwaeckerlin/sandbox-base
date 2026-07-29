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
