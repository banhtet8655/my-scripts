#!/usr/bin/env bash
# Auto install SOCKS5 Dante server on port 6969 with random user/pass
# Supports Debian/Ubuntu and CentOS/RHEL

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error_exit() {
    echo "ERROR: $*" >&2
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root."
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian) OS="debian"; PACKAGE_MANAGER="apt-get" ;;
            centos|rhel|fedora|amzn|rocky|almalinux) OS="redhat"
                if command -v dnf >/dev/null 2>&1; then
                    PACKAGE_MANAGER="dnf"
                else
                    PACKAGE_MANAGER="yum"
                fi
                ;;
            *) error_exit "Unsupported OS: $ID" ;;
        esac
    else
        error_exit "Cannot detect OS."
    fi
    log "Detected OS: $OS, package manager: $PACKAGE_MANAGER"
}

generate_password() {
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c12
}

generate_username() {
    echo "user_$(tr -dc 'a-z0-9' </dev/urandom | head -c8)"
}

install_packages() {
    local packages=("$@")
    log "Installing packages: ${packages[*]}"
    if [[ "$OS" = "debian" ]]; then
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
    else
        $PACKAGE_MANAGER install -y epel-release || true
        $PACKAGE_MANAGER install -y "${packages[@]}"
    fi
}

manage_firewall() {
    local port=$1
    log "Configuring firewall to open port $port/tcp"
    if [[ "$OS" = "debian" ]]; then
        if command -v ufw >/dev/null 2>&1; then
            ufw --force enable
            ufw allow "$port/tcp"
        else
            iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
            if command -v netfilter-persistent >/dev/null 2>&1; then
                netfilter-persistent save
            else
                iptables-save > /etc/iptables/rules.v4
            fi
        fi
    else
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-port="$port/tcp"
            firewall-cmd --reload
        else
            iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
            service iptables save || iptables-save > /etc/sysconfig/iptables
        fi
    fi
}

install_socks5() {
    local PORT=6969
    local USERNAME PASSWORD

    log "Starting SOCKS5 (Dante) installation on port $PORT"

    # Check if port 6969 is free
    if ss -tuln | grep -q ":$PORT "; then
        error_exit "Port $PORT is already in use. Please free it before running this script."
    fi

    # Generate username/password
    USERNAME=$(generate_username)
    PASSWORD=$(generate_password)

    log "Generated credentials - USER: $USERNAME , PASS: $PASSWORD"

    # Install packages
    if [[ "$OS" = "debian" ]]; then
        install_packages dante-server
    else
        install_packages dante-server
    fi

    # Create user without home and no login shell
    if ! id "$USERNAME" >/dev/null 2>&1; then
        useradd -M -N -s /usr/sbin/nologin "$USERNAME"
    fi

    echo "${USERNAME}:${PASSWORD}" | chpasswd

    # Get external interface
    EXT_IF=$(ip route | awk '/default/ {print $5; exit}')
    EXT_IF=${EXT_IF:-eth0}

    # Backup old config if exists
    if [[ -f /etc/danted.conf ]]; then
        cp /etc/danted.conf "/etc/danted.conf.bak.$(date +%F_%T)"
    fi

    # Write danted.conf
    cat > /etc/danted.conf <<EOF
logoutput: syslog /var/log/danted.log

internal: 0.0.0.0 port = $PORT
external: $EXT_IF

method: pam

user.privileged: root
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: connect disconnect error
    protocol: tcp udp
}

socks block {
    from: 0.0.0.0/0 to: 127.0.0.0/8
    log: connect error
}

socks block {
    from: 0.0.0.0/0 to: 169.254.0.0/16
    log: connect error
}
EOF

    chmod 644 /etc/danted.conf

    systemctl daemon-reload
    systemctl enable danted
    systemctl restart danted

    sleep 2
    if ! systemctl is-active --quiet danted; then
        error_exit "Dante SOCKS5 server failed to start"
    fi

    manage_firewall "$PORT"

    # Get public IP
    PUBLIC_IP=""
    for service in "https://api.ipify.org" "https://icanhazip.com" "https://ipecho.net/plain"; do
        PUBLIC_IP=$(curl -4 -s --connect-timeout 5 "$service" || true)
        if [[ $PUBLIC_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        fi
    done
    if [[ -z "$PUBLIC_IP" ]]; then
        PUBLIC_IP="YOUR_SERVER_IP"
    fi

    log "SOCKS5 (Dante) installed successfully!"
    echo ""
    echo "Connect using:"
    echo "socks5://${USERNAME}:${PASSWORD}@${PUBLIC_IP}:${PORT}"
}

main() {
    check_root
    detect_os
    install_socks5
}

main "$@"
