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
# OpenCode Docker Image — 原生 OpenAI provider + 自定义 baseURL
# -----------------------------------------------------------------------------

FROM debian:bookworm-slim

# 1. 安装基础工具（补上了关键的 gnupg）
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates jq netcat-openbsd gnupg \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. 安装 Caddy（现在 gpg 命令可用了）
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] \
        https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main" \
        > /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update && apt-get install -y caddy \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. 安装 OpenCode（动态提取资产链接，解决 404 问题）
# 注意：这里会自动筛选包含 linux 且包含 x64 或 amd64 的包
RUN ASSET_URL=$(curl -sf https://api.github.com/repos/sst/opencode/releases/latest \
        | jq -r '.assets[] | select(.name | test("linux.*(x64|amd64)")) | .browser_download_url') \
    && curl -fsSL "$ASSET_URL" -o /usr/local/bin/opencode \
    && chmod +x /usr/local/bin/opencode

# 4. 设置运行环境
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
