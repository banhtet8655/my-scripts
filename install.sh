#!/usr/bin/env bash
# SOCKS5 Proxy Auto Installer (Dante) - Port 6969, Random user/pass, No prompt

set -euo pipefail

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error_exit() { log "ERROR: $1"; exit 1; }

[[ $EUID -ne 0 ]] && error_exit "Run as root"

# Detect OS
detect_os() {
    . /etc/os-release
    case "$ID" in
        ubuntu|debian) OS="debian"; PM="apt-get" ;;
        centos|rhel|amzn|fedora|rocky|almalinux) OS="redhat"
            PM=$(command -v dnf || echo yum) ;;
        *) error_exit "Unsupported OS: $ID" ;;
    esac
}

get_ip() {
    for s in "https://api.ipify.org" "https://icanhazip.com"; do
        IP=$(curl -s --connect-timeout 5 "$s" || true)
        [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && break
    done
    [[ -z "${IP:-}" ]] && error_exit "Unable to get public IP"
}

install() {
    log "Installing packages..."
    [[ $OS == debian ]] && $PM update -qq
    $PM install -y dante-server curl iptables >/dev/null 2>&1 || error_exit "Failed to install"
}

open_port() {
    iptables -I INPUT -p tcp --dport 6969 -j ACCEPT
    iptables-save > /etc/iptables.rules
}

gen_user() { echo "user_$(tr -dc a-z0-9 </dev/urandom | head -c6)"; }
gen_pass() { tr -dc A-Za-z0-9 </dev/urandom | head -c12; }

install_socks5() {
    user=$(gen_user)
    pass=$(gen_pass)

    useradd -M -s /usr/sbin/nologin "$user" || true
    echo "$user:$pass" | chpasswd

    IFACE=$(ip route | awk '/default/ {print $5; exit}')
    [[ -z "$IFACE" ]] && error_exit "No default interface found"

    cat > /etc/danted.conf <<EOF
logoutput: syslog /var/log/danted.log
internal: 0.0.0.0 port = 6969
external: $IFACE
method: pam
user.privileged: root
user.notprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
}
EOF

    systemctl enable danted
    systemctl restart danted
    open_port
    echo "==================== SOCKS5 Proxy Created ===================="
    echo "Address : $IP"
    echo "Port    : 6969"
    echo "Username: $user"
    echo "Password: $pass"
    echo "Protocol: socks5"
    echo "=============================================================="
}

# MAIN
detect_os
get_ip
install
install_socks5
