# Changelog

- 2026-10-27 **1.0.3**
    - New: `OPENCODE_SMALL_MODEL` names the model of LiteLLM that OpenCode uses for small tasks such as session titles; without it OpenCode chooses as before

- 2026-10-27 **1.0.2**
    - The sandbox carries OpenCode, the coding agent, as `opencode`; with `OPENCODE_GATEWAY_URL` it reaches the models of LiteLLM and the Hindsight memory banks through a gateway that adds the keys, so the agent works on its own checkout without a key in the sandbox

- 2026-09-26 **1.0.1**
    - The image is published for amd64 and arm64 under one tag, built, tested and published automatically on every change and every week

- 2026-07-28 **1.0.0**
    - Initial release: the shared base for the hermes and openclaw SSH sandboxes
        - complete development toolset (compilers, language runtimes, media/LaTeX/office/OCR tools, network and database clients) with a package inventory in the image
        - hardened SSH daemon (key-only, no root login) and prepared runtime user
        - docker client and compose plugin for a docker-in-docker service such as mwaeckerlin/dockindock
    - Test suite: config contract (toolset, effective sshd hardening, docker client, drop-in contract) and an end to end test that logs in through real SSH and runs the toolchain
    - Feature and test registers (FEATURES.md, TESTS.md) with an automatic guard: every feature must have a test, and no test may be skipped
