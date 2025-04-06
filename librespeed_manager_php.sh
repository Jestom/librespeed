#!/bin/bash

INSTALL_DIR="/opt/speedtest"
FRONTEND_DIR="/var/www/html/librespeed"
SERVICE_FILE="/etc/systemd/system/speedtest.service"
DOWNLOAD_URL="https://github.com/librespeed/speedtest-go/releases/download/v1.1.5/speedtest-go_1.1.5_linux_amd64.tar.gz"
FRONTEND_REPO="https://github.com/librespeed/speedtest.git"
OS=""

function detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "❌ 无法检测操作系统"
        exit 1
    fi
}

function install_dependencies() {
    echo "📦 安装 nginx、PHP、tar、wget、git..."
    case "$OS" in
        ubuntu|debian)
            apt update -y
            apt install -y wget tar nginx php php-fpm git systemd
            ;;
        centos|rocky|almalinux|rhel)
            yum install -y epel-release
            yum install -y wget tar nginx php php-fpm git systemd
            systemctl enable php-fpm
            ;;
        *)
            echo "❌ 不支持的系统：$OS"
            exit 1
            ;;
    esac
}

function install_librespeed_php() {
    detect_os
    install_dependencies

    echo "📂 创建后端目录 $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    echo "⬇️ 下载后端程序"
    wget -q "$DOWNLOAD_URL" -O speedtest.tar.gz
    tar -xvzf speedtest.tar.gz
    chmod +x speedtest-backend

    echo "🌐 下载前端页面（含 PHP）"
    rm -rf "$FRONTEND_DIR"
    git clone "$FRONTEND_REPO" "$FRONTEND_DIR"

    echo "📄 设置默认首页（带 PHP）"
    cp "$FRONTEND_DIR/examples/example-singleServer-full.html" "$FRONTEND_DIR/index.html"

    echo "⚙️ 配置 nginx 支持 PHP"
    cat <<EOF > /etc/nginx/sites-enabled/default
server {
    listen 80 default_server;
    root $FRONTEND_DIR;
    index index.php index.html;
    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    echo "🧾 写入 systemd 服务"
    cat <<EOL > "$SERVICE_FILE"
[Unit]
Description=LibreSpeed Backend
After=network.target

[Service]
ExecStart=$INSTALL_DIR/speedtest-backend
WorkingDirectory=$INSTALL_DIR
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

    echo "🚀 启动服务"
    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable speedtest
    systemctl restart speedtest
    systemctl restart php8.2-fpm
    systemctl restart nginx

    IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "🎉 安装完成！访问测速页面：http://$IP/"
}

function start_librespeed() {
    systemctl start speedtest && echo "✅ 已启动"
}

function stop_librespeed() {
    systemctl stop speedtest && echo "🛑 已停止"
}

function restart_librespeed() {
    systemctl restart speedtest && echo "🔁 已重启"
}

function uninstall_librespeed_php() {
    echo "⚠️ 正在卸载 LibreSpeed..."
    systemctl stop speedtest
    systemctl disable speedtest
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    rm -rf "$INSTALL_DIR"
    rm -rf "$FRONTEND_DIR"

    echo "🔄 恢复 nginx 默认配置"
    cat <<EOF > /etc/nginx/sites-enabled/default
server {
    listen 80 default_server;
    root /var/www/html;
    index index.html;
    server_name _;
}
EOF

    systemctl restart nginx
    echo "✅ 卸载完成"
}

function show_menu() {
    echo ""
    echo "=============================================="
    echo " 🚀 LibreSpeed PHP 部署脚本"
    echo "=============================================="
    echo " 1. 安装 LibreSpeed（含 PHP）"
    echo " 2. 启动测速后端"
    echo " 3. 停止测速后端"
    echo " 4. 重启测速后端"
    echo " 5. 卸载 LibreSpeed"
    echo " 6. 退出脚本"
    echo "=============================================="
    echo -n "请输入选项 [1-6]: "
}

while true; do
    show_menu
    read choice
    case $choice in
        1) install_librespeed_php ;;
        2) start_librespeed ;;
        3) stop_librespeed ;;
        4) restart_librespeed ;;
        5) uninstall_librespeed_php ;;
        6) echo "👋 再见！"; exit 0 ;;
        *) echo "❌ 无效选项，请输入 1~6" ;;
    esac
    echo ""
    read -p "按回车键返回菜单..."
done
