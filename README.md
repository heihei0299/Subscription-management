# Clash Subscription Updater

一键拉取 Clash / Mihomo 订阅文件并定时更新。

## 快速开始

```bash
# 1. 安装（复制脚本和配置到系统路径，可选注册定时任务）
sudo ./install.sh

# 2. 编辑配置文件，填入订阅链接
sudo nano /etc/clash-subscription/clash-subscription.conf

# 3. 手动运行一次
sudo bash /etc/clash-subscription/update-clash-config

# 4. 验证
head -5 /etc/clash/config.yaml
```

运行后自动重启 `mihomo.service` 并输出其状态。

## 文件路径总览

| 项目 | 路径 | 说明 |
|------|------|------|
| **主脚本** | `/etc/clash-subscription/update-clash-config` | `install.sh` 复制至此 |
| **配置文件** | `/etc/clash-subscription/clash-subscription.conf` | `install.sh` 复制至此（已存在则跳过） |
| **订阅配置** | `/etc/clash/config.yaml` | 拉取结果（`OUTPUT_DIR` 可配置） |
| **备份文件** | `/etc/clash/config.yaml.bak` | 覆盖前自动备份 |
| **日志文件** | `/var/log/clash-subscription.log` | 运行日志（`LOG_FILE` 可配置） |
| **安装脚本** | `./install.sh` | 项目目录使用，不安装 |
| **卸载脚本** | `./uninstall.sh` | 项目目录使用 |
| **cron 安装** | `./install-cron.sh` | 单独注册定时任务 |
| **cron 移除** | `./uninstall-cron.sh` | 移除定时任务 |

## 用法

### 运行

```bash
# 使用默认配置
sudo bash /etc/clash-subscription/update-clash-config

# 临时指定订阅链接和输出目录
sudo bash /etc/clash-subscription/update-clash-config \
  -u "https://example.com/sub" -d /etc/clash

# 使用自定义配置文件（多实例）
sudo bash /etc/clash-subscription/update-clash-config -c /path/to/my.conf
```

### 命令行参数

| 参数 | 说明 |
|------|------|
| `-c, --conf FILE` | 配置文件路径（默认 `/etc/clash-subscription/clash-subscription.conf`） |
| `-u, --url URL` | 订阅链接（覆盖配置文件和环境变量） |
| `-d, --output-dir DIR` | 输出目录（覆盖配置文件和环境变量） |
| `--ua, --user-agent STR` | UA 伪装字符串 |
| `--interval SECONDS` | daemon 模式轮询间隔（秒） |
| `--log-file FILE` | 日志文件路径 |
| `--retry N` | 失败重试次数 |
| `--retry-delay SECONDS` | 重试间隔（默认 5 秒） |
| `--timeout SECONDS` | 连接超时（秒） |
| `--daemon` | 持续轮询模式（见下文） |
| `-h, --help` | 帮助信息 |

### 环境变量

所有配置项均可通过环境变量覆盖配置文件：

```bash
export CLASH_URL="https://example.com/sub"
export CLASH_OUTPUT_DIR="/data/clash"
export CLASH_UA="ClashMeta/1.0"
export CLASH_INTERVAL=43200
sudo bash /etc/clash-subscription/update-clash-config
```

完整列表：`CLASH_URL`、`CLASH_OUTPUT_DIR`、`CLASH_UA`、`CLASH_INTERVAL`、`CLASH_LOG_FILE`、`CLASH_RETRY`、`CLASH_RETRY_DELAY`、`CLASH_TIMEOUT`、`CLASH_CONF`。

### 配置优先级

**命令行参数 > 环境变量 > 配置文件 > 内建默认值**

## 配置文件参考

配置文件 `/etc/clash-subscription/clash-subscription.conf`：

```ini
# 订阅链接（必填）
SUBSCRIPTION_URL="https://example.com/sub"

# 输出目录（config.yaml 保存位置）
OUTPUT_DIR="/etc/clash"

# UA 伪装
USER_AGENT="ClashForAndroid/3.0.8"

# 日志文件
LOG_FILE="/var/log/clash-subscription.log"

# 重试次数
RETRY=3

# 重试间隔（秒）
RETRY_DELAY=5

# 连接超时（秒）
TIMEOUT=15

# daemon 模式轮询间隔（秒）
INTERVAL=21600
```

配置文件可复制改名用于多实例，通过 `-c` 指定路径：

```bash
sudo bash /etc/clash-subscription/update-clash-config -c /etc/my-clash.conf
```

## 定时更新

### 方式一：cron（推荐）

```bash
# 注册定时任务
sudo ./install-cron.sh

# 查看已注册的任务
sudo crontab -l | grep clash

# 移除定时任务
sudo ./uninstall-cron.sh
```

`INTERVAL` 配置项控制更新频率（秒），脚本会自动转换为合适的 cron 表达式：

- `INTERVAL=3600` → 每小时
- `INTERVAL=21600` → 每 6 小时（默认）
- `INTERVAL=86400` → 每天

### 方式二：daemon 模式

适用于没有 cron 的环境（Docker 容器等）：

```bash
sudo bash /etc/clash-subscription/update-clash-config --daemon
```

脚本持续运行，按 `INTERVAL` 秒间隔循环拉取。

## Mihomo 自动重启

每次成功拉取新配置后，脚本会自动执行以下操作：

```
systemctl restart mihomo.service
systemctl is-active mihomo.service
```

输出示例：

```
OK: config updated -> /etc/clash/config.yaml
[Mihomo] Restarting mihomo.service...
[Mihomo] Status: active
```

如果系统没有 systemd（如 Docker 容器），会跳过重启并输出提示。

## 日志

日志默认写入 `/var/log/clash-subscription.log`，格式：

```
[2025-01-15 10:30:00] [OK] Subscription saved to /etc/clash/config.yaml (size: 15234 bytes, HTTP 200)
[2025-01-15 10:30:00] [OK] Backed up existing config to /etc/clash/config.yaml.bak
[2025-01-15 10:30:01] [OK] Restarting mihomo.service...
[2025-01-15 10:30:01] [OK] mihomo.service status: active
[2025-01-15 12:00:00] [WARN] Attempt 1/3 — HTTP 503, retrying in ${RETRY_DELAY}s...
[2025-01-15 12:00:15] [FAIL] Failed to fetch subscription after 3 attempts (last HTTP 503)
```

## 卸载

```bash
# 完整卸载（交互式确认每一步）
sudo ./uninstall.sh

# 如果配置文件不在默认路径
sudo ./uninstall.sh -c /etc/clash-subscription/clash-subscription.conf
```

卸载内容：移除 crontab 任务 → 删除 `/etc/clash-subscription/update-clash-config` → 删除配置文件 → 可选删除 `/etc/clash/config.yaml`、备份和日志。
