# Shared SSH Sandbox Base Image

[mwaeckerlin/sandbox-base] is the common base for interactive AI agent sandboxes: a complete Ubuntu development environment behind a hardened SSH daemon, with a docker client ready for docker-in-docker and the coding agent [OpenCode]. The agent stacks [mwaeckerlin/hermes] and [mwaeckerlin/openclaw] derive their sandboxes from this image.

The heavy toolset (compilers, language runtimes, LaTeX, office, media and OCR tools) is built once here, so the derived sandboxes stay thin and are updated and tested in one place.

All features are listed in [FEATURES.md](FEATURES.md), all tests in [TESTS.md](TESTS.md).

## Role

The image is a base for derived sandboxes and ships no entrypoint of its own. A derived image adds its skills and an entrypoint that installs the user's authorized SSH key and starts `sshd`, as hermes and openclaw do. It builds on [mwaeckerlin/ubuntu-base].

## Usage

```dockerfile
FROM mwaeckerlin/sandbox-base
ENV CONTAINERNAME="my-sandbox"
ADD files/my-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

The entrypoint typically writes the authorized key, publishes selected variables (e.g. `DOCKER_HOST`) to `/etc/environment` for SSH sessions and ends with `exec /usr/sbin/sshd -D -e`.

For docker-in-docker, run a [mwaeckerlin/dockindock] service on a shared isolated network and set `DOCKER_HOST=tcp://<service>:<port>`, as the hermes and openclaw compose files do.

## OpenCode

The image carries [OpenCode], the coding agent, as the command `opencode`. It works where the agent works: on the agent's checkout, with this toolset and the agent's Docker. The command writes its configuration from the environment on every call:

| Variable | Meaning |
| --- | --- |
| `OPENCODE_GATEWAY_URL` | Gateway that adds the keys on the way to LiteLLM and Hindsight, such as an instance of `mwaeckerlin/opencode:gateway`; without it OpenCode runs with its own configuration |
| `OPENCODE_MODELS` | Comma separated model names of LiteLLM; the first is the default |
| `HINDSIGHT_SHARED_BANK` | Memory bank shared by all agents, MCP server `hindsight-shared`; empty: none |
| `HINDSIGHT_OWN_BANK` | Memory bank of this agent alone, MCP server `hindsight-own`; empty: none |

OpenCode sends a placeholder in place of every key, and the gateway replaces it, so the sandbox holds no key. `opencode --print-config` prints the configuration. A derived image publishes these variables to `/etc/environment`, so that they reach the SSH session. OpenCode never updates itself and downloads no model list and no language server, because a sandbox reaches no internet; a new release of OpenCode arrives with the next build of this image.

## Security Trade-Offs

- **Key-only SSH**: password and keyboard-interactive authentication and root login are disabled in the shipped `sshd_config`; only the runtime user with the provisioned key can log in.
- **The image runs as root** so the entrypoint can provision the key and start `sshd`; interactive sessions always land as the unprivileged runtime user.
- **Docker access is remote by design**: the sandbox only ships the client. Pair it with the rootless [mwaeckerlin/dockindock] daemon on an isolated network instead of mounting a docker socket or running a privileged daemon in the sandbox itself.
- **No key in the sandbox**: OpenCode reaches LiteLLM and Hindsight only through a gateway that adds the keys; whoever can read the sandbox finds no key.

## Tests

`npm test` runs the docs contract (every feature in [FEATURES.md](FEATURES.md) has a test in [TESTS.md](TESTS.md), no skipped tests), the config contract (toolset spot checks, effective sshd hardening, docker client, OpenCode and its configuration, drop-in contract) and an end to end test that starts the real sshd, logs in with a freshly generated key, executes the toolchain through the SSH session and lets OpenCode answer a prompt through a real LiteLLM with a mock model:

    npm test            # docs + config contract + SSH e2e

[mwaeckerlin/sandbox-base]: https://hub.docker.com/r/mwaeckerlin/sandbox-base "get the image from docker hub"
[mwaeckerlin/hermes]: https://github.com/mwaeckerlin/hermes
[mwaeckerlin/openclaw]: https://github.com/mwaeckerlin/openclaw
[mwaeckerlin/ubuntu-base]: https://github.com/mwaeckerlin/ubuntu-base
[mwaeckerlin/dockindock]: https://github.com/mwaeckerlin/dockindock
[OpenCode]: https://opencode.ai
