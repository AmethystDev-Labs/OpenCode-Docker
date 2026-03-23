#!/usr/bin/env bash
# =============================================================================
# entrypoint.sh — OpenCode container bootstrap
#
# 使用原生 openai provider（@ai-sdk/openai），仅覆盖 baseURL。
# 如果设置了 BASIC_AUTH_USER/PASS，则启动 Caddy sidecar 注入认证头，
# 绕过 OpenCode 反复弹认证弹窗的 Bug。
# =============================================================================
set -euo pipefail

# ── 默认值 ────────────────────────────────────────────────────────────────────
: "${OPENAI_BASE_URL:=https://api.openai.com/v1}"
: "${OPENAI_API_KEY:=sk-placeholder}"
: "${OPENAI_MODEL:=gpt-4o}"
: "${BASIC_AUTH_USER:=}"
: "${BASIC_AUTH_PASS:=}"
: "${CADDY_LOG_LEVEL:=ERROR}"

CADDY_PORT=18080
CONFIG_DIR="${HOME}/.config/opencode"
CONFIG_FILE="${CONFIG_DIR}/opencode.json"
AUTH_FILE="${HOME}/.local/share/opencode/auth.json"

mkdir -p "${CONFIG_DIR}"
mkdir -p "$(dirname "${AUTH_FILE}")"

# ── Basic Auth sidecar ────────────────────────────────────────────────────────
# OpenCode 的 ai-sdk 遇到上游 401 会不停弹认证窗口。
# 解决方案：Caddy 作为透明代理在出口注入 Basic Auth，
# OpenCode 只看到本地无认证端点。
if [[ -n "${BASIC_AUTH_USER}" && -n "${BASIC_AUTH_PASS}" ]]; then
    UPSTREAM="${OPENAI_BASE_URL%/}"
    B64_CREDS=$(printf '%s:%s' "${BASIC_AUTH_USER}" "${BASIC_AUTH_PASS}" | base64 -w0)

    cat > /tmp/Caddyfile <<EOF
{
    admin off
    auto_https off
}
:${CADDY_PORT} {
    log { output stderr; level ${CADDY_LOG_LEVEL} }
    reverse_proxy ${UPSTREAM} {
        header_up Authorization "Basic ${B64_CREDS}"
        header_up Host {upstream_hostport}
    }
}
EOF

    caddy run --config /tmp/Caddyfile --adapter caddyfile &
    CADDY_PID=$!
    trap "kill ${CADDY_PID} 2>/dev/null || true" EXIT

    # 等待 Caddy 就绪
    for _ in $(seq 1 30); do
        nc -z 127.0.0.1 ${CADDY_PORT} 2>/dev/null && break
        sleep 0.2
    done

    EFFECTIVE_URL="http://127.0.0.1:${CADDY_PORT}"
    echo "[entrypoint] Caddy sidecar ready — proxying ${UPSTREAM} with Basic Auth"
else
    EFFECTIVE_URL="${OPENAI_BASE_URL}"
    echo "[entrypoint] Direct mode — ${EFFECTIVE_URL}"
fi

# ── 写 opencode.json ──────────────────────────────────────────────────────────
# 使用内置 openai provider，只覆盖 baseURL。
# 这样用的是 @ai-sdk/openai 而非 openai-compatible，行为与官方 OpenAI 一致。
# apiKey 写在 auth.json（OpenCode 标准位置），config 里不重复存。
jq -n \
    --arg schema "https://opencode.ai/config.json" \
    --arg base_url "${EFFECTIVE_URL}" \
    --arg model "openai/${OPENAI_MODEL}" \
    '{
        "$schema": $schema,
        "model": $model,
        "provider": {
            "openai": {
                "options": {
                    "baseURL": $base_url
                }
            }
        }
    }' > "${CONFIG_FILE}"

# ── 写 auth.json ──────────────────────────────────────────────────────────────
# OpenCode 从这里读取各 provider 的 API Key
jq -n \
    --arg key "${OPENAI_API_KEY}" \
    '{ "openai": { "type": "api", "key": $key } }' > "${AUTH_FILE}"

echo "[entrypoint] opencode.json:"
cat "${CONFIG_FILE}"
echo ""

# ── 启动 ──────────────────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
    exec opencode
else
    exec "$@"
fi
