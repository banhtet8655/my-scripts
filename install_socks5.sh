#!/bin/bash

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "Vui lòng chạy script này bằng quyền root hoặc sudo." 
   exit 1
fi

echo "Cập nhật hệ thống và cài đặt dante-server..."
apt-get update
apt-get install -y dante-server

echo "Tạo user thuc với mật khẩu thuc (nếu chưa có)..."
# Kiểm tra user 'thuc' đã tồn tại chưa
if id "thuc" &>/dev/null; then
    echo "User 'thuc' đã tồn tại."
else
    # Tạo user thuc, tắt shell login (nếu cần)
    useradd -M -s /usr/sbin/nologin thuc
    echo "thuc:thuc" | chpasswd
    echo "Đã tạo user 'thuc' với mật khẩu 'thuc'."
fi

echo "Tạo file cấu hình cho dante-server với xác thực username/password, cổng 6969..."

cat > /etc/danted.conf <<EOL
logoutput: syslog

internal: 0.0.0.0 port = 6969
external: eth0

method: username
user.privileged: proxy
user.unprivileged: nobody
user.libwrap: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: connect disconnect error
    method: username
}
EOL

echo "Khởi động lại dịch vụ dante-server..."
systemctl restart danted

echo "Kiểm tra trạng thái dante-server..."
systemctl status danted --no-pager

echo "Proxy SOCKS5 đã được cài đặt trên cổng 6969 với user/pass là thuc/thuc."
