#!/bin/bash

INSTALL_DIR="/opt/speedtest"
SERVICE_FILE="/etc/systemd/system/speedtest.service"
DOWNLOAD_URL="https://github.com/librespeed/speedtest-go/releases/download/v1.1.0/speedtest-go_1.1.0_linux_amd64.tar.gz"

# 检测系统类型
function detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "❌ 无法检测操作系统，请手动安装依赖并重试。"
        exit 1
    fi
}

# 安装必要工具
function install_dependencies() {
    echo "📦 正在安装依赖（wget、tar、systemd）..."
    case "$OS" in
        ubuntu|debian)
            apt update -y
            apt install -y wget tar systemd
            ;;
        centos|rocky|almalinux|rhel)
            yum install -y wget tar systemd
            ;;
        *)
            echo "❌ 不支持的系统：$OS"
            exit 1
            ;;
    esac
}

function install_librespeed() {
    echo "🛠️ 安装目录：$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    echo "⬇️ 正在下载 LibreSpeed 后端..."
    wget -q --show-progress "$DOWNLOAD_URL" -O speedtest.tar.gz

    echo "📦 正在解压..."
    tar -xvzf speedtest.tar.gz
    chmod +x speedtest-backend

    echo "🧾 正在创建 systemd 服务..."
    cat <<EOL > "$SERVICE_FILE"
[Unit]
Description=LibreSpeed Backend Server
After=network.target

[Service]
ExecStart=$INSTALL_DIR/speedtest-backend
WorkingDirectory=$INSTALL_DIR
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

    echo "🔁 启用并启动服务..."
    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable speedtest
    systemctl start speedtest

    IP=$(hostname -I | awk '{print $1}')
    echo "✅ 安装完成！测速页面地址：http://$IP:8989"
}

function start_librespeed() {
    systemctl start speedtest && echo "✅ LibreSpeed 已启动"
}

function stop_librespeed() {
    systemctl stop speedtest && echo "🛑 LibreSpeed 已停止"
}

function restart_librespeed() {
    systemctl restart speedtest && echo "🔄 LibreSpeed 已重启"
}

function uninstall_librespeed() {
    echo "⚠️ 正在卸载 LibreSpeed..."
    systemctl stop speedtest
    systemctl disable speedtest
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    rm -rf "$INSTALL_DIR"
    echo "🧹 卸载完成"
}

function show_menu() {
    echo ""
    echo "=========================================="
    echo "    🚀 LibreSpeed 内网测速管理脚本 (通用版)"
    echo "=========================================="
    echo " 1. 安装 LibreSpeed"
    echo " 2. 启动 LibreSpeed"
    echo " 3. 停止 LibreSpeed"
    echo " 4. 重启 LibreSpeed"
    echo " 5. 卸载 LibreSpeed"
    echo " 6. 退出脚本"
    echo "=========================================="
    echo -n "请输入选项 [1-6]: "
}

# 初始化检测
detect_os
install_dependencies

# 菜单主循环
while true; do
    show_menu
    read choice
    case $choice in
        1) install_librespeed ;;
        2) start_librespeed ;;
        3) stop_librespeed ;;
        4) restart_librespeed ;;
        5) uninstall_librespeed ;;
        6) echo "👋 再见！"; exit 0 ;;
        *) echo "❌ 无效选项，请输入 1~6" ;;
    esac
    echo ""
    read -p "按回车键返回菜单..."
done
