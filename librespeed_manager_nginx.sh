#!/bin/bash

INSTALL_DIR="/opt/speedtest"
FRONTEND_DIR="/var/www/html/librespeed"
SERVICE_FILE="/etc/systemd/system/speedtest.service"
DOWNLOAD_URL="https://github.com/librespeed/speedtest-go/releases/download/v1.1.5/speedtest-go_1.1.5_linux_amd64.tar.gz"
OS=""

# 检测系统
function detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "❌ 无法检测操作系统，请手动安装依赖。"
        exit 1
    fi
}

# 安装依赖
function install_dependencies() {
    echo "📦 正在安装依赖（nginx、wget、tar、unzip、systemd）..."
    case "$OS" in
        ubuntu|debian)
            apt update -y
            apt install -y wget tar unzip nginx systemd
            ;;
        centos|rocky|almalinux|rhel)
            yum install -y wget tar unzip nginx systemd
            systemctl enable nginx
            ;;
        *)
            echo "❌ 不支持的系统：$OS"
            exit 1
            ;;
    esac
}

# 安装 LibreSpeed 后端 + 前端（legacy）
function install_librespeed_nginx() {
    detect_os
    install_dependencies

    echo "🛠️ 创建后端目录 $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    echo "⬇️ 下载后端 speedtest-go v1.1.5"
    wget -q --show-progress "$DOWNLOAD_URL" -O speedtest-go.tar.gz
    tar -xvzf speedtest-go.tar.gz
    chmod +x speedtest-go

    echo "🌐 下载 legacy 前端 zip 包"
    wget -q https://github.com/librespeed/speedtest-legacy/archive/refs/heads/master.zip -O /tmp/speedtest-legacy.zip
    unzip -o /tmp/speedtest-legacy.zip -d /tmp/
    rm -rf "$FRONTEND_DIR"
    mv /tmp/speedtest-legacy-master "$FRONTEND_DIR"

    echo "🎨 设置默认测速页面为纯 HTML（静态）"
    rm -f "$FRONTEND_DIR/index.html"
    cp "$FRONTEND_DIR/example-singleServer-pretty.html" "$FRONTEND_DIR/index.html"

    echo "⚙️ 配置 nginx（静态测速页面）"
    cat <<EOF > /etc/nginx/sites-enabled/default
server {
    listen 80 default_server;
    root $FRONTEND_DIR;
    index index.html;
    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    echo "🔄 重启 nginx"
    systemctl restart nginx

    echo "🧾 写入 systemd 服务"
    cat <<EOL > "$SERVICE_FILE"
[Unit]
Description=LibreSpeed Backend v1.1.5
After=network.target

[Service]
ExecStart=$INSTALL_DIR/speedtest-go
WorkingDirectory=$INSTALL_DIR
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

    echo "✅ 启动后端服务"
    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable speedtest
    systemctl start speedtest

    IP=$(hostname -I | awk '{print $1}')
    echo "🎉 安装完成！访问测速页面：http://$IP/"
}

function start_librespeed() {
    systemctl start speedtest && echo "✅ LibreSpeed 后端已启动"
}

function stop_librespeed() {
    systemctl stop speedtest && echo "🛑 LibreSpeed 后端已停止"
}

function restart_librespeed() {
    systemctl restart speedtest && echo "🔁 LibreSpeed 后端已重启"
}

function uninstall_librespeed_nginx() {
    echo "⚠️ 正在卸载 LibreSpeed（v1.1.5 + nginx）"
    systemctl stop speedtest
    systemctl disable speedtest
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload

    echo "🧹 删除测速服务文件夹：$INSTALL_DIR"
    rm -rf "$INSTALL_DIR"

    echo "🧹 删除前端目录：$FRONTEND_DIR"
    rm -rf "$FRONTEND_DIR"

    echo "♻️ 恢复 nginx 默认配置"
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
    echo " 🚀 LibreSpeed v1.1.5 分离部署管理脚本"
    echo "=============================================="
    echo " 1. 安装 LibreSpeed（后端+前端+Nginx）"
    echo " 2. 启动测速后端"
    echo " 3. 停止测速后端"
    echo " 4. 重启测速后端"
    echo " 5. 卸载全部组件"
    echo " 6. 退出脚本"
    echo "=============================================="
    echo -n "请输入选项 [1-6]: "
}

# 菜单主循环
while true; do
    show_menu
    read choice
    case $choice in
        1) install_librespeed_nginx ;;
        2) start_librespeed ;;
        3) stop_librespeed ;;
        4) restart_librespeed ;;
        5) uninstall_librespeed_nginx ;;
        6) echo "👋 再见！"; exit 0 ;;
        *) echo "❌ 无效选项，请输入 1~6" ;;
    esac
    echo ""
    read -p "按回车键返回菜单..."
done
