# syntax=docker/dockerfile:1
#
# skill-auditor sandbox — a minimal, hardened runtime for EXECUTING an untrusted skill's
# bundled scripts under review. Runs as a non-root user with no host credentials, on an
# egress-gated network (see ../compose.yml). Skills bundle helper scripts in bash / Python /
# Node, so all three runtimes are present.

FROM python:3.12-slim-bookworm@sha256:8a7e7cc04fd3e2bd787f7f24e22d5d119aa590d429b50c95dfe12b3abe52f48b

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
