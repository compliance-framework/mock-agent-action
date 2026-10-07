# Stage 1: the mock-agent image that provides the binary (mirrors agent-action's
# `FROM ghcr.io/compliance-framework/agent:<ver> AS source`).
# mock-agent has no published image yet, so this starts on alpine.
# replaced by ghcr.io/compliance-framework/mock-agent:<version> via ccf-bump
FROM ghcr.io/compliance-framework/mock-agent:0.1.0 AS source

# Stage 2: small final image that runs the binary.
FROM alpine:3.20

# The bracketed names are wildcards, so a missing file is skipped instead of
# failing the build: the seed source (alpine) has no binary, and the mock-agent
# image has no /etc/alpine-release. Only the FROM line above changes on a bump.
COPY --from=source /ap[p]/mock-agen[t] /et[c]/alpine-releas[e] /usr/local/bin/

# Fail the build if the source is a real mock-agent image without an executable
# /app/mock-agent, rather than shipping an action that only prints a stub.
RUN if [ -e /usr/local/bin/mock-agent ]; then \
      [ -x /usr/local/bin/mock-agent ] || { echo "/app/mock-agent is not executable" >&2; exit 1; }; \
    elif [ ! -f /usr/local/bin/alpine-release ]; then \
      echo "source image has no /app/mock-agent" >&2; exit 1; \
    fi; \
    rm -f /usr/local/bin/alpine-release

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
