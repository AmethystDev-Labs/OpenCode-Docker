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
# -----------------------------------------------------------------------------
# OpenCode Docker Image - Multi-Arch Stable
# -----------------------------------------------------------------------------

FROM debian:bookworm-slim

# 1. 安装基础工具
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates jq netcat-openbsd gnupg tar \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. 安装 Caddy
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] \
        https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
        > /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update && apt-get install -y caddy \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. 安装 OpenCode (核心逻辑：根据架构下载对应包)
ARG TARGETARCH
RUN case "${TARGETARCH}" in \
      "amd64") ARCH_PATTERN="linux.*(x64|amd64)" ;; \
      "arm64") ARCH_PATTERN="linux.*(arm64|aarch64)" ;; \
      *) ARCH_PATTERN="linux.*x64" ;; \
    esac && \
    ASSET_URL=$(curl -sL https://api.github.com/repos/anomalyco/opencode/releases/latest \
        | jq -r --arg PAT "$ARCH_PATTERN" '.assets[] | select(.name | test($PAT)) | .browser_download_url' | head -n 1) \
    && echo "Downloading for $TARGETARCH from: $ASSET_URL" \
    && if echo "$ASSET_URL" | grep -q ".tar.gz"; then \
         curl -fsSL "$ASSET_URL" | tar -xz -C /usr/local/bin/ && mv /usr/local/bin/opencode* /usr/local/bin/opencode; \
       else \
         curl -fsSL "$ASSET_URL" -o /usr/local/bin/opencode; \
       fi \
    && chmod +x /usr/local/bin/opencode

# 4. 设置运行环境
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
