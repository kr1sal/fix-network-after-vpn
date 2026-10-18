#!/usr/bin/env bash
# Fix Network After VPN (macOS)
# Чистит маршруты, DNS-кэш, удаляет осиротевшие utun-интерфейсы, перезапускает сетевой сервис.
# Запуск: sudo bash fix-network.sh

set -u

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo bash $0)." >&2
    exit 1
fi

step() { printf '\033[36m==> %s\033[0m\n' "$1"; }
ok()   { printf '    \033[32mOK\033[0m\n'; }
warn() { printf '    \033[33m%s\033[0m\n' "$1"; }

step "Flush routing table"
route -n flush >/dev/null 2>&1 && ok || warn "route flush returned non-zero"

step "Flush DNS cache (dscacheutil + mDNSResponder)"
dscacheutil -flushcache 2>/dev/null || true
killall -HUP mDNSResponder 2>/dev/null && ok || warn "mDNSResponder was not running"

step "Destroy orphan utun interfaces"
for iface in $(ifconfig -l | tr ' ' '\n' | grep -E '^utun[0-9]+$'); do
    ifconfig "$iface" destroy 2>/dev/null && echo "    removed $iface" || true
done
ok

step "Restart primary network service"
PRIMARY_SERVICE=$(networksetup -listnetworkserviceorder \
    | awk -F'[()]' '/^\(1\)/ {print $2; exit}' \
    | sed 's/^ *//; s/ *$//')

if [[ -n "${PRIMARY_SERVICE:-}" ]]; then
    echo "    service: $PRIMARY_SERVICE"
    networksetup -setnetworkserviceenabled "$PRIMARY_SERVICE" off
    sleep 2
    networksetup -setnetworkserviceenabled "$PRIMARY_SERVICE" on
    ok
else
    warn "Could not detect primary network service, skipping restart"
fi

echo
printf '\033[32mDone. Try opening a website now.\033[0m\n'
