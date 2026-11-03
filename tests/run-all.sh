#!/usr/bin/env bash
# Runs every test group of package.json in turn; a red group does not stop
# the groups after it, so one run names everything there is to repair.
#
# Usage: tests/run-all.sh [--list] [--from <group>] [--to <group>]
#   --list           prints the groups in their order
#   --from, --to     runs the groups from one to another, both included, such
#                    as the rest of a run that was interrupted
set -uo pipefail
cd "$(dirname "$0")/.."

GROUPS_IN_ORDER=(docs contract e2e)
FROM="${GROUPS_IN_ORDER[0]}"
TO="${GROUPS_IN_ORDER[-1]}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --list) printf '%s\n' "${GROUPS_IN_ORDER[@]}"; exit 0 ;;
        --from) FROM="${2:-}"; shift 2 ;;
        --to) TO="${2:-}"; shift 2 ;;
        *) echo "usage: tests/run-all.sh [--list] [--from <group>] [--to <group>]" >&2; exit 2 ;;
    esac
done
index() {
    local i
    for i in "${!GROUPS_IN_ORDER[@]}"; do
        [[ "${GROUPS_IN_ORDER[$i]}" == "$1" ]] && { echo "$i"; return 0; }
    done
    echo "tests/run-all.sh: unknown group «$1», the groups are: ${GROUPS_IN_ORDER[*]}" >&2
    return 1
}
FIRST=$(index "${FROM}") || exit 2
LAST=$(index "${TO}") || exit 2
if [[ ${FIRST} -gt ${LAST} ]]; then
    echo "tests/run-all.sh: --from ${FROM} comes after --to ${TO}" >&2
    exit 2
fi

FAILED=()
for group in "${GROUPS_IN_ORDER[@]:${FIRST}:$((LAST - FIRST + 1))}"; do
    echo "==> npm run test:${group}"
    npm run --silent "test:${group}" || FAILED+=("test:${group}")
done
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "==> red: ${FAILED[*]}"
    exit 1
fi
echo "==> every group from ${FROM} to ${TO} green"
