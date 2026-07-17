#!/usr/bin/env bash
set -euo pipefail

override_dir="$HOME/.config/systemd/user/hermes-dashboard.service.d"

rollback() {
  install -m 600 "$HOME/.local/libexec/hermes-ui/override-rollback.conf" "$override_dir/override.conf"
  systemctl --user daemon-reload
  systemctl --user restart hermes-dashboard.service
}

trap rollback ERR
install -m 600 "$HOME/.local/libexec/hermes-ui/override-final.conf" "$override_dir/override.conf"
systemctl --user daemon-reload
systemctl --user restart hermes-dashboard.service

for _ in $(seq 1 20); do
  if curl -sf --max-time 2 http://127.0.0.1:9119/api/status >/dev/null; then
    break
  fi
  sleep 1
done

curl -sf --max-time 5 http://127.0.0.1:9119/api/status >/dev/null
sudo -n tailscale serve --http=9119 --bg http://127.0.0.1:9119
trap - ERR

printf 'SERVICE=%s\n' "$(systemctl --user is-active hermes-dashboard.service)"
printf 'LISTENERS\n'
ss -lntp | grep -E ':(443|9119) '
printf 'SERVE\n'
sudo -n tailscale serve status


