#!/bin/bash
#
# 清理 sing-box / sbctl 残留配置
#

echo "🧹 清理 sing-box / sbctl 残留配置..."

# 1. 杀掉残留的 sing-box 进程
if pgrep -x "sing-box" > /dev/null; then
    echo "   停止 sing-box 进程..."
    sudo pkill -9 sing-box
    sleep 1
else
    echo "   没有运行中的 sing-box 进程"
fi

# 2. 杀掉残留的后台监控进程
MONITOR_PIDS=$(pgrep -f "start_process_monitor" 2>/dev/null || true)
if [ -n "$MONITOR_PIDS" ]; then
    echo "   停止后台监控进程..."
    echo "$MONITOR_PIDS" | xargs -r sudo kill -9 2>/dev/null || true
else
    echo "   没有运行中的监控进程"
fi

# 3. 删除残留的 tun 接口
if ip link show tun0 &>/dev/null; then
    echo "   删除 tun0 接口..."
    sudo ip link delete tun0 2>/dev/null
else
    echo "   没有残留的 tun0 接口"
fi

# 4. 清理可能残留的路由
echo "   清理残留路由..."
sudo ip route del default dev tun0 2>/dev/null || true
sudo ip route del 172.19.0.0/30 2>/dev/null || true
sudo ip route del fd00::/126 2>/dev/null || true

# 5. 清理 iptables 规则 (sbctl 创建的 SBCTL_OUTPUT 链)
if sudo iptables -t nat -L SBCTL_OUTPUT &>/dev/null; then
    echo "   清理 iptables nat 规则..."
    sudo iptables -t nat -D OUTPUT -j SBCTL_OUTPUT 2>/dev/null || true
    sudo iptables -t nat -F SBCTL_OUTPUT 2>/dev/null || true
    sudo iptables -t nat -X SBCTL_OUTPUT 2>/dev/null || true
else
    echo "   没有残留的 iptables nat 规则"
fi

# 6. 清理 nftables 规则 (sing-box auto_route 可能创建的)
if command -v nft &>/dev/null; then
    sudo nft list tables 2>/dev/null | grep -q "sing-box" && {
        echo "   清理 nftables 规则..."
        sudo nft delete table inet sing-box 2>/dev/null || true
    }
fi

# 7. 清理 cgroup (可选，不强制删除以免影响其中的进程)
CGROUP_PATH="/sys/fs/cgroup/sbctl_proxy"
if [ -d "$CGROUP_PATH" ]; then
    # 检查是否还有进程在 cgroup 中
    PROCS=$(cat "$CGROUP_PATH/cgroup.procs" 2>/dev/null | wc -l)
    if [ "$PROCS" -eq 0 ]; then
        echo "   删除空的 cgroup..."
        sudo rmdir "$CGROUP_PATH" 2>/dev/null || true
    else
        echo "   cgroup 中还有 $PROCS 个进程，跳过删除"
    fi
fi

# 8. 清理临时文件
echo "   清理临时文件..."
rm -f /tmp/sbctl_known_pids 2>/dev/null || true
rm -f /tmp/tmp.* 2>/dev/null || true

echo "✅ 清理完成"
