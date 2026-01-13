# sbctl - sing-box 进程级代理控制器

一个基于 sing-box 的进程级代理工具，可以**只让指定的应用走代理**，其他应用完全不受影响。

## 特性

- **进程级代理**：使用 cgroup + iptables 实现真正的进程级代理控制
- **自动监控**：后台自动检测并将新启动的目标进程加入代理组
- **Web UI**：集成 yacd 控制面板，实时查看连接状态
- **无侵入**：不影响其他应用的网络连接（包括其他代理工具如 v2rayn）
- **自动清理**：退出时自动清理 iptables 规则和临时文件
- **自动加载配置**：sbctl 自动读取同目录下的 .env 文件
- **systemd 服务**：支持安装为系统服务，开机自启

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

### 安装为系统服务（推荐）

```bash
# 安装服务
sudo ./install-service.sh

# 编辑配置
sudo vim /opt/sbctl/.env

# 获取订阅配置（如有网络问题可指定代理）
sudo /opt/sbctl/sbctl fetch
# 或
sudo /opt/sbctl/sbctl fetch http://127.0.0.1:7890

# 启动服务
sudo systemctl start sbctl

# 开机自启
sudo systemctl enable sbctl

# 查看状态
sudo systemctl status sbctl

# 查看日志
sudo journalctl -u sbctl -f
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

# fetch 命令使用的代理（可选）
FETCH_PROXY=http://127.0.0.1:7890
```

## 使用方法

> **提示**：`sbctl` 会自动加载同目录下的 `.env` 文件，可直接使用 `./sbctl` 或通过 `./start.sh` 包装使用。

### 获取配置

```bash
# 直接获取
./sbctl fetch

# 通过代理获取（网络问题时使用）
./sbctl fetch http://127.0.0.1:7890
./sbctl fetch socks5://127.0.0.1:1080

# 或使用环境变量
FETCH_PROXY=http://127.0.0.1:7890 ./sbctl fetch
```

### 查看可用节点

```bash
./sbctl list
```

### 启动进程级代理

```bash
# 使用 .env 中的默认配置
./start.sh tun

# 指定节点
./start.sh tun "HK-01"

# 指定节点和进程
./start.sh tun "HK-01" antigravity chrome

# 或直接使用 sbctl
./sbctl tun "HK-01" antigravity chrome
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
| `./sbctl fetch [proxy]` | 获取远程配置，可选指定代理 |
| `./sbctl list` | 列出可用代理节点 |
| `./sbctl tun <节点> <进程...>` | 启动进程级代理 |
| `./sbctl proxy <节点>` | 启动 HTTP/SOCKS 代理模式 |
| `./sbctl mix <节点> <进程...>` | 混合模式 |
| `./clean.sh` | 清理残留配置 |

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `REMOTE_URL` | 订阅链接 | (必填) |
| `PROXY_NAME` | 默认代理节点 | - |
| `PROCESS_NAMES` | 目标进程列表 | - |
| `CLASH_API_PORT` | Web UI 端口 | 9090 |
| `CLASH_API_SECRET` | Web UI 密码 | (空) |
| `FETCH_PROXY` | fetch 命令使用的代理 | - |
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

### 查看当前连接

```bash
curl -s http://127.0.0.1:9090/connections | jq '.connections[] | {host: .metadata.host, process: .metadata.process, chains: .chains}'
```

## License

MIT License

## 致谢

本项目 fork 自 [kafkaliu/like-a-rolling-stone](https://github.com/kafkaliu/like-a-rolling-stone)，感谢原作者 [@kafkaliu](https://github.com/kafkaliu) 的出色工作。

主要改进：
- 添加 Linux 进程级代理支持（cgroup + iptables）
- 集成 yacd Web UI
- 添加进程自动监控功能
- 添加 systemd 服务支持
- fetch 命令支持代理
- sbctl 自动加载 .env 配置
