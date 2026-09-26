# Tests

Register of all tests, grouped by kind and sorted by the [FEATURES.md](FEATURES.md) number each test covers. `npm test` runs everything; the guard `tests/docs-contract.sh` fails when a feature has no test entry here or when any test carries a skip/xfail marker — tests are never skipped.

## End-to-end

The suite starts the real sshd and exercises the image through an SSH session.

- **F1** `tests/run-e2e.sh` › SSH-E2E-OK — the toolchain (docker client, compose, git, python, node, gcc, latex, jq) runs inside a real SSH session.
- **F2** `tests/run-e2e.sh` › SSH-E2E-OK — login works with a freshly generated key as the unprivileged user; the whole flow (authorized key → sshd → session) is the real delivery path.
- **F3** `tests/run-e2e.sh` › SSH-E2E-OK — `docker --version` and `docker compose version` answer inside the SSH session.

## Image contract

- **F1** `tests/config-contract.sh` › tools_dev, tools_lang, tools_media, tools_latex, tools_utils, tools_db, inventory_file — one spot check per package set plus the inventory.
- **F2** `tests/config-contract.sh` › sshd_present, sshd_no_password, sshd_no_root, sshd_pubkey, ssh_dir — the hardening directives are effective in the shipped `sshd_config` and `~/.ssh` is prepared.
- **F3** `tests/config-contract.sh` › docker_client, compose_plugin, docker_group — client, plugin and group membership.
- **F4** `tests/config-contract.sh` › environment_file, port_22_exposed, healthcheck_defined — the drop-in contract for derived images.

## Workflow contract

- **F5** `tests/workflow-contract.sh` of `mwaeckerlin/scratch` — the reusable workflow selects exactly the images a repository publishes; this repository calls it from `.github/workflows/docker.yml`.
