#!/bin/bash

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# In logo
echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}             ⚡ SOCKS5 PROXY AUTO INSTALLER ⚡          ${CYAN}║${NC}"
echo -e "${CYAN}║${WHITE}      🚀 Powered by S2CODETAEM | Port: 6969            ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Tạo user/pass SOCKS5 ngẫu nhiên
proxy_user="user$(openssl rand -hex 2)"
proxy_pass="$(openssl rand -base64 6)"

echo -e "${BLUE}➤ User: ${WHITE}$proxy_user${NC}"
echo -e "${BLUE}➤ Pass: ${WHITE}$proxy_pass${NC}"
echo ""

# Cập nhật & cài Dante
echo -e "${YELLOW}[1/4] ➤ Cài đặt Dante SOCKS5 Server...${NC}"
apt update && apt install -y dante-server

# Tạo file cấu hình Dante
echo -e "${YELLOW}[2/4] ➤ Đang cấu hình Dante SOCKS5 trên port 6969...${NC}"
cat <<EOF > /etc/danted.conf
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = 6969
external: $(ip route get 1 | awk '{print $5; exit}')
method: username
user.notprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
EOF

# Tạo user SOCKS5
echo -e "${YELLOW}[3/4] ➤ Tạo user SOCKS5...${NC}"
useradd -M -s /usr/sbin/nologin "$proxy_user"
echo "$proxy_user:$proxy_pass" | chpasswd

# Khởi động Dante
echo -e "${YELLOW}[4/4] ➤ Khởi động dịch vụ Dante...${NC}"
systemctl restart danted
systemctl enable danted

# Lấy IP public
ip_address=$(curl -s ifconfig.me)

# Hiển thị thông tin SOCKS5 proxy
echo -e "${GREEN}✅ SOCKS5 Proxy đã cài thành công!${NC}"
echo ""
echo -e "${PURPLE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${WHITE}           SOCKS5 Proxy Thông Tin Kết Nối               ${PURPLE}║${NC}"
echo -e "${PURPLE}╠═══════════════════════════════════════════════════════╣${NC}"
echo -e "${PURPLE}║${CYAN} 📍 IP:       ${WHITE}$ip_address${PURPLE}"
echo -e "${PURPLE}║${CYAN} 🔌 Port:     ${WHITE}6969${PURPLE}"
echo -e "${PURPLE}║${CYAN} 👤 Username: ${WHITE}$proxy_user${PURPLE}"
echo -e "${PURPLE}║${CYAN} 🔑 Password: ${WHITE}$proxy_pass${PURPLE}"
echo -e "${PURPLE}║${CYAN} 🧰 Loại:     ${WHITE}SOCKS5${PURPLE}"
echo -e "${PURPLE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}🎉 SOCKS5 Proxy đã sẵn sàng! Dùng tool, phần mềm, SSH... đều OK.${NC}"
