# syntax=docker/dockerfile:1
#
# skill-auditor sandbox — a minimal, hardened runtime for EXECUTING an untrusted skill's
# bundled scripts under review. Runs as a non-root user with no host credentials, on an
# egress-gated network (see ../compose.yml). Skills bundle helper scripts in bash / Python /
# Node, so all three runtimes are present.

# checkov:skip=CKV_DOCKER_2: ephemeral observation sandbox (sleep infinity) — no service to health-check, and a periodic HEALTHCHECK would only add execution noise while watching untrusted code. Liveness is the operator's/compose's concern.
FROM python:3.15-slim-bookworm@sha256:96599df822d0e1c6bb700014a05c7f3c8cabc6e0f7ff3c4f9f69cee033b4b5d9

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends bash nodejs npm ca-certificates; \
    rm -rf /var/lib/apt/lists/*; \
    useradd --system --create-home --home-dir /home/auditor auditor

USER auditor
WORKDIR /target

# The agent execs into this container to run + observe the skill's bundled scripts; it stays
# up so behavior can be watched. It never receives host credentials.
CMD ["sleep", "infinity"]
