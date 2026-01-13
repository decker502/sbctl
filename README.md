# sbctl - sing-box 进程级代理控制器

一个基于 sing-box 的进程级代理工具，可以**只让指定的应用走代理**，其他应用完全不受影响。

## 特性

- **进程级代理**：使用 cgroup + iptables 实现真正的进程级代理控制
- **自动监控**：后台自动检测并将新启动的目标进程加入代理组
- **Web UI**：集成 yacd 控制面板，实时查看连接状态
- **无侵入**：不影响其他应用的网络连接（包括其他代理工具如 v2rayn）
- **自动清理**：退出时自动清理 iptables 规则和临时文件

## 系统要求

- Linux (已测试 Ubuntu 24.04)
- sing-box 1.10+
- jq
- cgroup v2
- iptables

## 安装

```bash
# 克隆仓库
git clone git@github.com:decker502/sbctl.git
cd sbctl

# 复制配置文件
cp .env.example .env

# 编辑配置
vim .env
```

## 配置

编辑 `.env` 文件：

```bash
# 订阅链接（必填）
REMOTE_URL=你的订阅链接

# 默认代理节点名
PROXY_NAME="HK-01"

# 要代理的进程名列表（支持正则，空格分隔）
PROCESS_NAMES="antigravity chrome"

# Web UI 端口（可选）
CLASH_API_PORT=9090
```

## 使用方法

### 获取配置

```bash
./start.sh fetch
```

### 查看可用节点

```bash
./start.sh list
```

### 启动进程级代理

```bash
# 使用 .env 中的默认配置
./start.sh tun

# 指定节点
./start.sh tun "HK-01"

# 指定节点和进程
./start.sh tun "HK-01" antigravity chrome
```

### 启动后

- **Web UI**: http://127.0.0.1:9090/ui
- 在 Connections 页面查看连接状态
- 新启动的目标进程会自动加入代理组

### 清理残留

```bash
./clean.sh
```

## 工作原理

```
┌─────────────────────────────────────────────────────────────┐
│                        系统网络                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐                    ┌─────────────────┐    │
│  │ antigravity │──┐                 │  其他应用        │    │
│  │ (目标进程)   │  │                 │  (v2rayn 等)    │    │
│  └─────────────┘  │                 └────────┬────────┘    │
│                   │                          │              │
│                   ▼                          │              │
│         ┌─────────────────┐                  │              │
│         │ cgroup: sbctl   │                  │              │
│         │ + iptables      │                  │              │
│         └────────┬────────┘                  │              │
│                  │                           │              │
│                  ▼                           ▼              │
│         ┌─────────────────┐         ┌───────────────┐      │
│         │    sing-box     │         │    直连       │      │
│         │  (redirect 端口) │         │  (不经过代理)  │      │
│         └────────┬────────┘         └───────────────┘      │
│                  │                                          │
│                  ▼                                          │
│         ┌─────────────────┐                                 │
│         │   代理服务器     │                                 │
│         └─────────────────┘                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 命令参考

| 命令 | 说明 |
|------|------|
| `./start.sh fetch` | 获取远程配置 |
| `./start.sh list` | 列出可用代理节点 |
| `./start.sh tun [节点] [进程...]` | 启动进程级代理 |
| `./start.sh proxy <节点>` | 启动 HTTP/SOCKS 代理模式 |
| `./start.sh mix <节点> <进程...>` | 混合模式 |
| `./clean.sh` | 清理残留配置 |

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `REMOTE_URL` | 订阅链接 | (必填) |
| `PROXY_NAME` | 默认代理节点 | - |
| `PROCESS_NAMES` | 目标进程列表 | - |
| `CLASH_API_PORT` | Web UI 端口 | 9090 |
| `CLASH_API_SECRET` | Web UI 密码 | (空) |
| `SING_BOX_BIN` | sing-box 路径 | sing-box |

## 故障排除

### 代理不生效

1. 检查进程是否已加入 cgroup：
   ```bash
   cat /sys/fs/cgroup/sbctl_proxy/cgroup.procs
   ```

2. 检查 iptables 规则：
   ```bash
   sudo iptables -t nat -L SBCTL_OUTPUT -v
   ```

3. 查看 sing-box 日志中的连接信息

### 网络异常

运行清理脚本：
```bash
./clean.sh
```

### 查看当前规则

```bash
curl -s http://127.0.0.1:9090/rules | jq '.'
```

## License

MIT License
