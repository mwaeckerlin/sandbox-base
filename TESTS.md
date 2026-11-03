# Tests

Register of all tests, grouped by kind and sorted by the [FEATURES.md](FEATURES.md) number each test covers. `npm test` runs the groups `docs`, `contract` and `e2e` in this order, each also on its own as `npm run test:<group>`; a red group does not stop the groups after it, none depends on another, and `npm test -- --from <group> --to <group>` runs a part of them, both included. The guard `tests/docs-contract.sh` fails when a feature has no test entry here or when any test carries a skip/xfail marker — tests are never skipped.

## End-to-end

The suite starts the real sshd and exercises the image through an SSH session.

- **F1** `tests/run-e2e.sh` › SSH-E2E-OK — the toolchain (docker client, compose, git, python, node, gcc, latex, jq) runs inside a real SSH session.
- **F2** `tests/run-e2e.sh` › SSH-E2E-OK — login works with a freshly generated key as the unprivileged user; the whole flow (authorized key → sshd → session) is the real delivery path.
- **F3** `tests/run-e2e.sh` › SSH-E2E-OK — `docker --version` and `docker compose version` answer inside the SSH session.
- **F6** `tests/run-e2e.sh` › OpenCode answers through LiteLLM — in the same SSH session, `opencode run "Say hello"` with `OPENCODE_GATEWAY_URL` pointing at a real LiteLLM with a mock model prints the answer of the mock model.
- **F6** `tests/run-e2e.sh` › opencode models lists LiteLLM alone — in the same SSH session, `opencode models` lists `litellm/test-model` and no model of another provider, such as those of OpenCode Zen.

## Image contract

- **F1** `tests/config-contract.sh` › tools_dev, tools_lang, tools_media, tools_latex, tools_utils, tools_db, inventory_file — one spot check per package set plus the inventory.
- **F2** `tests/config-contract.sh` › sshd_present, sshd_no_password, sshd_no_root, sshd_pubkey, ssh_dir — the hardening directives are effective in the shipped `sshd_config` and `~/.ssh` is prepared.
- **F3** `tests/config-contract.sh` › docker_client, compose_plugin, docker_group — client, plugin and group membership.
- **F6** `tests/config-contract.sh` › opencode_runs, opencode_no_update, opencode_config_through_gateway, opencode_litellm_the_only_provider, opencode_small_model, opencode_no_small_model_by_default, opencode_no_memory_without_banks, opencode_without_gateway_own_config, opencode_invalid_bank_refused, opencode_invalid_gateway_refused — the binary runs, updates and downloads are off, the configuration names the gateway, LiteLLM as the only enabled provider, the models, the default model, the small model only when one is named and among the models, both memory banks and only the placeholder for the key, no memory bank is configured when none is named, no configuration is written without a gateway, and a bank id or a gateway address that would change the target is refused.
- **F7** `tests/config-contract.sh` › opencode_gateway_mcp_servers, opencode_gateway_mcp_gitlab_alone, opencode_no_gateway_mcp_by_default, opencode_unknown_gateway_mcp_refused, opencode_bank_named_like_a_forge_refused — `github` and `gitea`, given with spaces, twice and with an empty entry, become the remote MCP servers `github` and `gitea` at the gateway's `/mcp/github` and `/mcp/gitea` with the placeholder alone, beside the memory bank; `gitlab` alone becomes the one MCP server; without the setting none is configured; `bitbucket`, `github gitea`, `*` and `GitHub` and a memory bank called `github`, `gitea` or `gitlab` stop the start with a message that names them.
- **F4** `tests/config-contract.sh` › environment_file, port_22_exposed, healthcheck_defined — the drop-in contract for derived images.

## Workflow contract

- **F5** `tests/workflow-contract.sh` of `mwaeckerlin/scratch` — the reusable workflow selects exactly the images a repository publishes; this repository calls it from `.github/workflows/docker.yml`.
