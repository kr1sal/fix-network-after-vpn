#!/usr/bin/env bash
# Fix Network After VPN (Linux)
# Чистит маршруты, удаляет осиротевшие tun/wg/tap-интерфейсы, флашит DNS и
# перезапускает NetworkManager (или systemd-networkd как фолбэк).
# Запуск: sudo bash fix-network.sh

set -u

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo bash $0)." >&2
    exit 1
fi

step() { printf '\033[36m==> %s\033[0m\n' "$1"; }
ok()   { printf '    \033[32mOK\033[0m\n'; }
warn() { printf '    \033[33m%s\033[0m\n' "$1"; }

step "Flush route cache"
ip route flush cache && ok || warn "ip route flush cache failed"

step "Remove orphan VPN interfaces (tun*, wg*, tap*, ppp*)"
for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(tun|tap|wg|ppp)[0-9A-Za-z_-]*$'); do
    ip link delete "$iface" 2>/dev/null && echo "    removed $iface" || warn "could not remove $iface"
done
ok

step "Remove default routes pointing to removed VPN ifaces"
while read -r line; do
    [[ -z "$line" ]] && continue
    echo "    deleting: $line"
    ip route del $line 2>/dev/null || true
done < <(ip route show default | grep -E 'dev (tun|tap|wg|ppp)')
ok

step "Flush DNS caches"
if command -v resolvectl >/dev/null 2>&1; then
    resolvectl flush-caches && ok || warn "resolvectl flush-caches failed"
elif command -v systemd-resolve >/dev/null 2>&1; then
    systemd-resolve --flush-caches && ok || warn "systemd-resolve flush failed"
else
    warn "systemd-resolved not detected, skipping DNS flush"
fi

restart_network() {
    if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager; then
        step "Restart NetworkManager"
        nmcli networking off
        sleep 2
        nmcli networking on
        ok
    elif systemctl is-active --quiet systemd-networkd; then
        step "Restart systemd-networkd"
        systemctl restart systemd-networkd && ok || warn "restart failed"
    else
        warn "No supported network manager detected. Restart your network stack manually."
    fi
}

restart_network

echo
printf '\033[32mDone. Try opening a website now.\033[0m\n'
