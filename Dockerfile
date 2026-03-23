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

# 安装工具
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates jq netcat-openbsd gnupg tar \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 安装 Caddy
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] \
        https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
        > /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update && apt-get install -y caddy \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 安装 OpenCode
ARG TARGETARCH
RUN case "${TARGETARCH}" in \
      "amd64") BIN_NAME="opencode-linux-x64.tar.gz" ;; \
      "arm64") BIN_NAME="opencode-linux-arm64.tar.gz" ;; \
      *) exit 1 ;; \
    esac && \
    ASSET_URL=$(curl -sL https://api.github.com/repos/anomalyco/opencode/releases/latest \
        | jq -r --arg NAME "$BIN_NAME" '.assets[] | select(.name == $NAME) | .browser_download_url') && \
    curl -fsSL "$ASSET_URL" | tar -xz -C /usr/local/bin/ && \
    # 处理可能的目录嵌套，确保 /usr/local/bin/opencode 可用
    if [ ! -f /usr/local/bin/opencode ]; then mv /usr/local/bin/opencode-* /usr/local/bin/opencode || true; fi && \
    chmod +x /usr/local/bin/opencode

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
