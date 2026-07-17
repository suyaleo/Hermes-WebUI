#!/usr/bin/env bash
set -euo pipefail

set -a
source "$HOME/.hermes/.env"
set +a

base_url="https://ubuntu.tail8cc5f1.ts.net"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

login_payload=$(jq -nc \
  --arg provider basic \
  --arg username "$HERMES_DASHBOARD_BASIC_AUTH_USERNAME" \
  --arg password "$HERMES_DASHBOARD_BASIC_AUTH_PASSWORD" \
  '{provider:$provider,username:$username,password:$password,next:"/"}')

curl -fsS \
  -c "$tmp_dir/cookies" \
  -H 'Content-Type: application/json' \
  -d "$login_payload" \
  "$base_url/auth/password-login" > "$tmp_dir/login.json"
jq -e '.ok == true and .next == "/"' "$tmp_dir/login.json" >/dev/null
printf 'LOGIN=ok\n'

curl -fsS -b "$tmp_dir/cookies" "$base_url/" > "$tmp_dir/index.html"
grep -q 'manifest.webmanifest' "$tmp_dir/index.html"
grep -q 'assets/index-' "$tmp_dir/index.html"
printf 'AUTHENTICATED_UI=ok\n'

manifest_code=$(curl -sS -b "$tmp_dir/cookies" -o "$tmp_dir/manifest" -w '%{http_code}' "$base_url/manifest.webmanifest")
test "$manifest_code" = 200
jq -e '.display == "standalone"' "$tmp_dir/manifest" >/dev/null
printf 'PWA_MANIFEST=ok\n'

curl -fsS \
  -b "$tmp_dir/cookies" \
  -X POST \
  "$base_url/api/auth/ws-ticket" > "$tmp_dir/ws-ticket.json"
ws_ticket=$(jq -er '.ticket' "$tmp_dir/ws-ticket.json")

set +e
curl -sS --http1.1 \
  -D "$tmp_dir/ws-headers" \
  -o /dev/null \
  --max-time 3 \
  -H 'Connection: Upgrade' \
  -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Version: 13' \
  -H 'Sec-WebSocket-Key: SGVybWVzV2ViU29ja2V0MQ==' \
  -H 'Origin: https://ubuntu.tail8cc5f1.ts.net' \
  "$base_url/api/ws?ticket=$ws_ticket"
ws_rc=$?
set -e

if grep -qE '^HTTP/1\.1 101' "$tmp_dir/ws-headers"; then
  printf 'WEBSOCKET_UPGRADE=ok curl_rc=%s\n' "$ws_rc"
else
  printf 'WEBSOCKET_UPGRADE=failed curl_rc=%s\n' "$ws_rc"
  sed -n '1,20p' "$tmp_dir/ws-headers"
  exit 1
fi


