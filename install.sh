#!/bin/bash

# Màu sắc hiển thị
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# --- PHẦN GIAO DIỆN GIỮ NGUYÊN (cắt bớt để ngắn hơn) ---
echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}         ⚡ ${YELLOW}S2CODETAEM ${RED}★ ${BLUE}SOCKS5 PROXY INSTALLER ${WHITE}⚡        ${CYAN}║${NC}"
echo -e "${CYAN}║${WHITE}    ${GREEN}🚀 Developed by TẠ NGỌC LONG - Premium Solutions 🚀   ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}⚠️  QUAN TRỌNG: Mở port 6969 trước khi chạy script${NC}"
read -p "➤ Bạn đã mở port 6969 chưa? [Y/N]: " confirm_ready
if [[ "${confirm_ready,,}" != "y" ]]; then
    echo -e "${RED}❌ Đã hủy. Vui lòng mở port 6969 rồi chạy lại script.${NC}"
    exit 1
fi

# Xác thực tên (giữ nguyên)
read -p "➤ Nhập họ và tên đầy đủ: " client_full_name
if [[ -z "$client_full_name" ]]; then
    echo -e "${RED}❌ Tên không hợp lệ!${NC}"
    exit 1
fi

# Biến cấu hình
socks_port="6969"
socks_user="tangoclong"
socks_pass="2000"

# Cập nhật hệ thống
echo -e "${GREEN}➤ Đang cập nhật hệ thống...${NC}"
apt update && apt install -y dante-server

# Cấu hình Dante SOCKS5
echo -e "${GREEN}➤ Tạo cấu hình Dante SOCKS5...${NC}"
cat <<EOF > /etc/danted.conf
logoutput: /var/log/danted.log
internal: 0.0.0.0 port = $socks_port
external: eth0

method: username
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: connect
    log: connect disconnect error
}
EOF

# Tạo user hệ thống cho SOCKS5
echo -e "${GREEN}➤ Tạo tài khoản SOCKS5...${NC}"
useradd -M -s /usr/sbin/nologin "$socks_user"
echo "$socks_user:$socks_pass" | chpasswd

# Mở port nếu cần
ufw allow $socks_port/tcp 2>/dev/null || iptables -A INPUT -p tcp --dport $socks_port -j ACCEPT

# Khởi động dịch vụ
systemctl restart danted
systemctl enable danted

# Lấy IP
ip_address=$(curl -s ifconfig.me)

# Kiểm tra hoạt động
echo -e "${CYAN}➤ Đang kiểm tra SOCKS5 proxy hoạt động...${NC}"
proxy_check=$(curl -s --socks5 $ip_address:$socks_port https://api.ipify.org)

if [[ "$proxy_check" == "$ip_address" ]]; then
    status="✅ SOCKS5 hoạt động tốt"
else
    status="❌ SOCKS5 không hoạt động"
fi

# Xuất thông tin
echo -e "${PURPLE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${WHITE}        THÔNG TIN SOCKS5 PROXY - $client_full_name       ${PURPLE}║${NC}"
echo -e "${PURPLE}╠═══════════════════════════════════════════════════════╣${NC}"
echo -e "${PURPLE}║${CYAN} 📡 IP:       ${WHITE}$ip_address${PURPLE}"
echo -e "${PURPLE}║${CYAN} 🔌 Port:     ${WHITE}$socks_port${PURPLE}"
echo -e "${PURPLE}║${CYAN} 👤 Username: ${WHITE}$socks_user${PURPLE}"
echo -e "${PURPLE}║${CYAN} 🔑 Password: ${WHITE}$socks_pass${PURPLE}"
echo -e "${PURPLE}║${CYAN} ⚙️  Status:   ${WHITE}$status${PURPLE}"
echo -e "${PURPLE}╚═══════════════════════════════════════════════════════╝${NC}"

# Liên hệ
echo ""
echo -e "${BLUE}🎉 Cảm ơn bạn đã sử dụng dịch vụ SOCKS5 của S2CODE TEAM! 🎉${NC}"
