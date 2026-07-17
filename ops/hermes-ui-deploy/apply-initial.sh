#!/usr/bin/env bash
set -euo pipefail

systemctl --user daemon-reload
systemctl --user restart hermes-dashboard.service

for _ in $(seq 1 20); do
  if curl -sf --max-time 2 http://127.0.0.1:9119/api/status >/dev/null; then
    break
  fi
  sleep 1
done

systemctl --user is-active hermes-dashboard.service
pid=$(systemctl --user show -p MainPID --value hermes-dashboard.service)
printf 'PID=%s\n' "$pid"
printf 'ENV='
tr '\0' '\n' < "/proc/$pid/environ" | grep '^HERMES_WEB_DIST='
printf 'LISTEN='
ss -lntp | grep ':9119 '
printf 'API='
curl -sS --max-time 5 http://127.0.0.1:9119/api/status |
  python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["version"], d["auth_providers"])'
asset=$(find "$HOME/apps/hermes-ui/app/dist/assets" -maxdepth 1 -name 'index-*.css' -printf '%f\n' | head -n1)
printf 'ASSET=%s ' "$asset"
curl -sS -o /dev/null -w 'HTTP:%{http_code} SIZE:%{size_download}\n' "http://127.0.0.1:9119/assets/$asset"
printf 'MANIFEST='
curl -sS -o /dev/null -w 'HTTP:%{http_code} TYPE:%{content_type}\n' http://127.0.0.1:9119/manifest.webmanifest
printf 'RECENT_LOG\n'
journalctl --user -u hermes-dashboard.service -n 30 --no-pager | tail -n 20


