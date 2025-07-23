#!/bin/bash

# Tự động chạy lại bằng sudo nếu không phải root
if [ "$EUID" -ne 0 ]; then
    echo "🔁 Script không chạy bằng root. Đang thử lại với sudo..."
    exec sudo "$0" "$@"
fi

# Cài đặt dante-server và công cụ tạo mật khẩu
apt update -y && apt install -y dante-server pwgen curl

# Tạo user/password ngẫu nhiên
user="user$(shuf -i 1000-9999 -n 1)"
pass=$(pwgen 10 1)

# Thêm user hệ thống (không tạo home, không login shell)
useradd -M -s /usr/sbin/nologin "$user"
echo "$user:$pass" | chpasswd

# Cấu hình dante
cat > /etc/danted.conf <<EOF
logoutput: /var/log/danted.log

internal: 0.0.0.0 port = 6969
external: eth0

method: username

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    log: connect disconnect error
    method: username
}
EOF

# Tự động chọn interface nếu không phải eth0
iface=$(ip route | grep default | awk '{print $5}' | head -n1)
sed -i "s/external: eth0/external: $iface/" /etc/danted.conf

# Tạo service danted
cat > /etc/systemd/system/danted.service <<EOF
[Unit]
Description=Dante SOCKS5 Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/danted -f /etc/danted.conf
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Khởi động dịch vụ
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable danted
systemctl restart danted

# Lấy IP công cộng
ip=$(curl -s ifconfig.me)

# Hiển thị thông tin
echo ""
echo "🎉 SOCKS5 Proxy đã được cài đặt thành công!"
echo "────────────────────────────────────────────"
echo "🌐 IP         : $ip"
echo "🔌 Port       : 6969"
echo "👤 Username   : $user"
echo "🔑 Password   : $pass"
echo "📎 Proxy URL  : socks5://$user:$pass@$ip:6969"
echo "────────────────────────────────────────────"
