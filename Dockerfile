# ─────────────────────────────────────────────────────────────────────────────
# OpenCode Docker Image
# Supports custom OpenAI baseURL via env vars, with Caddy sidecar to
# transparently inject Basic Auth (workaround for OpenCode's auth popup bug).
#
# Environment Variables:
#   OPENAI_BASE_URL      upstream API base URL (default: https://api.openai.com/v1)
#   OPENAI_API_KEY       API key (injected into config as literal value)
#   OPENAI_MODEL         default model ID (default: gpt-4o)
#   BASIC_AUTH_USER      username for upstream Basic Auth (optional)
#   BASIC_AUTH_PASS      password for upstream Basic Auth (optional)
#   PROVIDER_NAME        display name for the provider (default: Custom OpenAI)
#   PROVIDER_ID          provider key in config (default: custom-openai)
#   EXTRA_MODELS         JSON object of extra models e.g. '{"o3":{"name":"O3"}}'
#                        merged into the default model entry
# ─────────────────────────────────────────────────────────────────────────────

FROM debian:bookworm-slim AS base

# ── system deps ───────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates jq debian-keyring debian-archive-keyring apt-transport-https \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Caddy ─────────────────────────────────────────────────────────────────────
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
        | tee /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update && apt-get install -y caddy \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── OpenCode ──────────────────────────────────────────────────────────────────
# Install latest stable release via the official install script
RUN curl -fsSL https://opencode.ai/install | bash \
    && mv /root/.local/bin/opencode /usr/local/bin/opencode \
    || true
# Fallback: grab the binary directly from GitHub releases if script fails
RUN if ! command -v opencode &>/dev/null; then \
        LATEST=$(curl -sf https://api.github.com/repos/sst/opencode/releases/latest \
                 | jq -r '.tag_name'); \
        curl -fsSL "https://github.com/sst/opencode/releases/download/${LATEST}/opencode-linux-x64" \
             -o /usr/local/bin/opencode \
        && chmod +x /usr/local/bin/opencode; \
    fi

# ── entrypoint ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
