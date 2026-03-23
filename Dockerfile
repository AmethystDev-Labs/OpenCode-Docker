# ─────────────────────────────────────────────────────────────────────────────
# OpenCode Docker Image — 原生 OpenAI provider + 自定义 baseURL
#
# Environment Variables:
#   OPENAI_BASE_URL      覆盖 @ai-sdk/openai 的请求端点（默认 https://api.openai.com/v1）
#   OPENAI_API_KEY       API Key
#   OPENAI_MODEL         默认模型（默认 gpt-4o）
#   BASIC_AUTH_USER      上游 Basic Auth 用户名（可选，不设则跳过 Caddy）
#   BASIC_AUTH_PASS      上游 Basic Auth 密码（可选）
# ─────────────────────────────────────────────────────────────────────────────

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates jq netcat-openbsd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Caddy（仅 Basic Auth 模式需要）────────────────────────────────────────────
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] \
        https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
        > /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update && apt-get install -y caddy \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── OpenCode ──────────────────────────────────────────────────────────────────
RUN LATEST=$(curl -sf https://api.github.com/repos/sst/opencode/releases/latest \
             | jq -r '.tag_name') \
    && curl -fsSL \
        "https://github.com/sst/opencode/releases/download/${LATEST}/opencode-linux-x64" \
        -o /usr/local/bin/opencode \
    && chmod +x /usr/local/bin/opencode

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
