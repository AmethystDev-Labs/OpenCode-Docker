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
# OpenCode Docker Image - 2026 稳定版
# -----------------------------------------------------------------------------

FROM debian:bookworm-slim

# 1. 安装基础工具（含 gnupg 和解压用的 tar）
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

# 3. 安装 OpenCode（修正仓库路径 + 处理压缩包）
# 注意：改用了 anomalyco/opencode 并添加了 -L 处理重定向
RUN ASSET_URL=$(curl -sL https://api.github.com/repos/anomalyco/opencode/releases/latest \
        | jq -r '.assets[] | select(.name | test("linux.*(x64|amd64)")) | .browser_download_url' | head -n 1) \
    && echo "Downloading from: $ASSET_URL" \
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
