#!/usr/bin/env zsh
set -euo pipefail

APP_PATH=${APP_PATH:-"build/DerivedData/Build/Products/Release/ssrMac.app"}
RESULT_DIR=${RESULT_DIR:-".e2e/results"}
TEST_URL=${TEST_URL:-"https://www.youtube.com/generate_204"}
E2E_TIMEOUT=${E2E_TIMEOUT:-60}
PROXY_MODE=${PROXY_MODE:-global}

mkdir -p "$RESULT_DIR"

LOG_FILE="$RESULT_DIR/e2e-youtube.log"
APP_RESULT_FILE="$RESULT_DIR/app-result.json"
SSR_LINK_FILE_FOR_APP=${SSR_LINK_FILE:-}
APP_PID=""

log() {
    printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" | tee -a "$LOG_FILE"
}

fail() {
    log "FAIL: $*"
    exit 1
}

cleanup() {
    if [[ -z "${APP_PID:-}" ]]; then
        return
    fi
    log "stopping ssrMac pid=$APP_PID"
    osascript -e 'tell application id "com.ssrlive.macClient" to quit' >/dev/null 2>&1 || kill "$APP_PID" 2>/dev/null || true
}

trap cleanup EXIT

if [[ ! -d "$APP_PATH" ]]; then
    fail "app bundle not found: $APP_PATH"
fi

if [[ -z "$SSR_LINK_FILE_FOR_APP" ]]; then
    if [[ -z "${SSR_LINK:-}" ]]; then
        fail "set SSR_LINK_FILE or SSR_LINK"
    fi
    SSR_LINK_FILE_FOR_APP="$RESULT_DIR/ssr-link.txt"
    printf '%s\n' "$SSR_LINK" > "$SSR_LINK_FILE_FOR_APP"
    chmod 600 "$SSR_LINK_FILE_FOR_APP"
fi

if [[ ! -f "$SSR_LINK_FILE_FOR_APP" ]]; then
    fail "SSR link file not found: $SSR_LINK_FILE_FOR_APP"
fi

log "starting ssrMac E2E run; app=$APP_PATH result=$APP_RESULT_FILE test_url=$TEST_URL"

HELPER_SCRIPT="$APP_PATH/Contents/Resources/install_helper.sh"
HELPER_PATH="/Library/Application Support/ssrMac/ssr_mac_sysconf"
if [[ "${SKIP_HELPER_INSTALL:-NO}" != "YES" ]]; then
    if [[ -x "$HELPER_SCRIPT" ]]; then
        log "installing helper with sudo; helper=$HELPER_PATH"
        sudo bash "$HELPER_SCRIPT" >> "$LOG_FILE" 2>&1
    else
        log "helper install script missing; continuing so app can report the failure"
    fi
fi

rm -f "$APP_RESULT_FILE"
open -n "$APP_PATH" --args \
    --e2e-ssr-url-file "$SSR_LINK_FILE_FOR_APP" \
    --e2e-result-file "$APP_RESULT_FILE" \
    --e2e-timeout "$E2E_TIMEOUT" \
    --e2e-proxy-mode "$PROXY_MODE"

deadline=$((SECONDS + E2E_TIMEOUT + 10))
while [[ ! -f "$APP_RESULT_FILE" ]]; do
    if (( SECONDS >= deadline )); then
        fail "timed out waiting for app result file"
    fi
    sleep 1
done

status=$(plutil -extract status raw "$APP_RESULT_FILE")
message=$(plutil -extract message raw "$APP_RESULT_FILE")
listen_port=$(plutil -extract listenPort raw "$APP_RESULT_FILE")
APP_PID=$(plutil -extract pid raw "$APP_RESULT_FILE")

log "app result: status=$status listen_port=$listen_port pid=$APP_PID message=$message"
if [[ "$status" != "ready" ]]; then
    fail "app did not become ready"
fi

curl_log="$RESULT_DIR/curl-youtube.log"
http_code=$(curl \
    --socks5-hostname "127.0.0.1:$listen_port" \
    --connect-timeout 15 \
    --max-time 45 \
    --location \
    --output /dev/null \
    --silent \
    --show-error \
    --write-out '%{http_code}' \
    "$TEST_URL" 2> "$curl_log") || {
        log "curl failed; see $curl_log"
        exit 1
    }

log "youtube probe HTTP status: $http_code"
case "$http_code" in
    200|204|301|302|303|307|308)
        log "PASS: YouTube probe succeeded through SSR proxy"
        ;;
    *)
        fail "unexpected HTTP status from YouTube probe: $http_code"
        ;;
esac

log "E2E run completed"