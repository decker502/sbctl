#!/bin/bash
#
# 安装 sbctl 为 systemd 服务
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/sbctl"
SERVICE_FILE="/etc/systemd/system/sbctl.service"

echo "🚀 安装 sbctl 服务..."

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 sudo 运行此脚本"
    exit 1
fi

# 创建安装目录
echo "   创建安装目录 $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# 复制文件
echo "   复制文件..."
cp "$SCRIPT_DIR/sbctl" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/clean.sh" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/ui" "$INSTALL_DIR/" 2>/dev/null || true

# 设置权限
chmod +x "$INSTALL_DIR/sbctl"
chmod +x "$INSTALL_DIR/clean.sh"

# 复制 .env 文件（如果存在）
if [ -f "$SCRIPT_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env" "$INSTALL_DIR/"
    chmod 600 "$INSTALL_DIR/.env"
    echo "   已复制 .env 配置文件"
else
    if [ -f "$SCRIPT_DIR/.env.example" ]; then
        cp "$SCRIPT_DIR/.env.example" "$INSTALL_DIR/.env"
        chmod 600 "$INSTALL_DIR/.env"
        echo "⚠️  已创建 .env 文件，请编辑 $INSTALL_DIR/.env 填入配置"
    fi
fi

# 创建 sing-box 配置目录
mkdir -p /root/.sing_box

# 安装 systemd 服务
echo "   安装 systemd 服务..."
cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=sbctl - sing-box 进程级代理控制器
Documentation=https://github.com/decker502/sbctl
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/sbctl
EnvironmentFile=/opt/sbctl/.env
ExecStart=/bin/bash -c '/opt/sbctl/sbctl tun "$PROXY_NAME" $PROCESS_NAMES'
ExecStop=/bin/kill -SIGTERM $MAINPID
ExecStopPost=/opt/sbctl/clean.sh
Restart=on-failure
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd
systemctl daemon-reload

echo ""
echo "✅ 安装完成！"
echo ""
echo "使用方法："
echo "  1. 编辑配置文件:  sudo vim $INSTALL_DIR/.env"
echo "  2. 获取订阅配置:  sudo $INSTALL_DIR/sbctl fetch"
echo "  3. 启动服务:      sudo systemctl start sbctl"
echo "  4. 开机自启:      sudo systemctl enable sbctl"
echo "  5. 查看状态:      sudo systemctl status sbctl"
echo "  6. 查看日志:      sudo journalctl -u sbctl -f"
echo ""
echo "Web UI: http://127.0.0.1:9090/ui"
