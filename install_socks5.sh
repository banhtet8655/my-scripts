#!/bin/bash

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "Vui lòng chạy script này bằng quyền root hoặc sudo." 
   exit 1
fi

echo "Cập nhật hệ thống và cài đặt dante-server..."
apt-get update
apt-get install -y dante-server

echo "Tạo file cấu hình cho dante-server với cổng 6969..."

cat > /etc/danted.conf <<EOL
logoutput: syslog

internal: 0.0.0.0 port = 6969
external: eth0

method: username none
user.privileged: proxy
user.unprivileged: nobody
user.libwrap: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
EOL

echo "Khởi động lại dịch vụ dante-server..."
systemctl restart danted

echo "Kiểm tra trạng thái dante-server..."
systemctl status danted --no-pager

echo "SOCKS5 proxy đã được cài đặt và chạy trên cổng 6969."
echo "Bạn có thể kết nối proxy với địa chỉ IP máy chủ và cổng 6969."
