# Features

Numbered register of every end-user visible feature; a number is never reused. Every feature is covered by tests listed in [TESTS.md](TESTS.md); the guard `tests/docs-contract.sh` fails when a feature has no test.

- **F1 — Complete interactive development toolset.** Compilers and build systems (C/C++, make/cmake/ninja, autotools), language runtimes (python, node, php, ruby, go, rust), media and document processing (imagemagick, ffmpeg, inkscape, libreoffice, OCR), LaTeX, network and database clients, and everyday utilities — with the full package inventory written to `/etc/installed-ubuntu-packages`.
- **F2 — Hardened SSH access.** Key-only authentication (passwords and keyboard-interactive disabled), no root login, sshd and the runtime user's `~/.ssh` prepared — a derived sandbox only needs to install the authorized key and start `sshd`.
- **F3 — Docker client for docker-in-docker.** The docker CLI and the compose plugin are installed and the runtime user is in the docker group; point `DOCKER_HOST` at a daemon service (e.g. [mwaeckerlin/dockindock](https://github.com/mwaeckerlin/dockindock)) and containers can be built and run from inside the sandbox.
- **F4 — Drop-in base for derived sandboxes.** Port 22 and the readiness healthcheck are preconfigured, `/etc/environment` is prepared for the entrypoint to publish variables to SSH sessions — a derived image (e.g. hermes, openclaw) only adds its skills and its entrypoint.
- **F5 — Published for amd64 and arm64.** Every push builds the image natively for both architectures and publishes it under one tag on Docker Hub, with the reusable workflow of `mwaeckerlin/scratch`.
