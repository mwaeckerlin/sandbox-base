# Shared SSH Sandbox Base Image

[mwaeckerlin/sandbox-base] is the common base for interactive AI agent
sandboxes: a complete Ubuntu development environment behind a hardened SSH
daemon, with a docker client ready for docker-in-docker. The agent stacks
[mwaeckerlin/hermes] and [mwaeckerlin/openclaw] derive their sandboxes from
this image.

Building the heavy toolset (compilers, language runtimes, LaTeX, office,
media and OCR tools) once in a shared base keeps the derived sandboxes
thin and identical where they should be identical — one place to update,
one place to test.

All features are listed in [FEATURES.md](FEATURES.md), all tests in
[TESTS.md](TESTS.md).

**Role: base image for derived sandboxes** — it ships no entrypoint of its
own. A derived image adds its skills and an entrypoint that installs the
user's authorized SSH key and starts `sshd` (see hermes/openclaw for the
pattern). It builds on [mwaeckerlin/ubuntu-base].

## Usage

```dockerfile
FROM mwaeckerlin/sandbox-base
ENV CONTAINERNAME="my-sandbox"
ADD files/my-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

The entrypoint typically writes the authorized key, publishes selected
variables (e.g. `DOCKER_HOST`) to `/etc/environment` for SSH sessions and
ends with `exec /usr/sbin/sshd -D -e`.

For docker-in-docker, run a [mwaeckerlin/dockindock] service on a shared
isolated network and set `DOCKER_HOST=tcp://<service>:<port>` — see the
hermes and openclaw compose files.

## Security Trade-Offs

- **Key-only SSH**: password and keyboard-interactive authentication and
  root login are disabled in the shipped `sshd_config`; only the runtime
  user with the provisioned key can log in.
- **The image runs as root** so the entrypoint can provision the key and
  start `sshd`; interactive sessions always land as the unprivileged
  runtime user.
- **Docker access is remote by design**: the sandbox only ships the
  client. Pair it with the rootless [mwaeckerlin/dockindock] daemon on an
  isolated network instead of mounting a docker socket or running a
  privileged daemon in the sandbox itself.

## Tests

`npm test` runs the docs contract (every feature in
[FEATURES.md](FEATURES.md) has a test in [TESTS.md](TESTS.md), no skipped
tests), the config contract (toolset spot checks, effective sshd
hardening, docker client, drop-in contract) and an end to end test that
starts the real sshd, logs in with a freshly generated key and executes
the toolchain through the SSH session:

    npm test            # docs + config contract + SSH e2e

[mwaeckerlin/sandbox-base]: https://hub.docker.com/r/mwaeckerlin/sandbox-base "get the image from docker hub"
[mwaeckerlin/hermes]: https://github.com/mwaeckerlin/hermes
[mwaeckerlin/openclaw]: https://github.com/mwaeckerlin/openclaw
[mwaeckerlin/ubuntu-base]: https://github.com/mwaeckerlin/ubuntu-base
[mwaeckerlin/dockindock]: https://github.com/mwaeckerlin/dockindock
