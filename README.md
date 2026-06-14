# Clash Subscription Updater

一键拉取 Clash 订阅文件并定时更新。

## 快速开始

```bash
# 1. 安装
sudo ./install.sh

# 2. 编辑配置，填入订阅链接
sudo nano /etc/clash-subscription.conf

# 3. 手动运行一次
sudo update-clash-config

# 4. 验证
head -5 /etc/clash/config.yaml
```

## 文件说明

| 文件 | 用途 |
|------|------|
| `update-clash-config.sh` | 主脚本 — 拉取订阅并保存为 `config.yaml` |
| `clash-subscription.conf` | 默认配置文件 |
| `install.sh` | 安装到系统路径，可选注册 cron |
| `install-cron.sh` | 单独注册定时任务 |
| `uninstall.sh` | 完整卸载（脚本 + 配置 + cron + 数据） |
| `uninstall-cron.sh` | 仅移除定时任务 |

## 用法

### 直接运行

```bash
# 使用默认配置 (/etc/clash-subscription.conf)
sudo update-clash-config

# 指定订阅 URL 和输出目录（临时覆盖）
sudo update-clash-config -u "https://example.com/sub" -d /etc/clash

# 指定自定义配置文件（多实例）
sudo update-clash-config -c /path/to/my-clash.conf
```

### 命令行参数

| 参数 | 说明 |
|------|------|
| `-c, --conf FILE` | 配置文件路径（默认 `/etc/clash-subscription.conf`） |
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
update-clash-config
```

完整列表：`CLASH_URL`、`CLASH_OUTPUT_DIR`、`CLASH_UA`、`CLASH_INTERVAL`、`CLASH_LOG_FILE`、`CLASH_RETRY`、`CLASH_RETRY_DELAY`、`CLASH_TIMEOUT`、`CLASH_CONF`。

### 配置优先级

**命令行参数 > 环境变量 > 配置文件 > 内建默认值**

## 定时更新

### 方式一：cron（推荐）

```bash
# 安装时选择注册 cron，或之后单独运行：
sudo ./install-cron.sh

# 查看已注册的定时任务
sudo crontab -l | grep clash

# 移除
sudo ./uninstall-cron.sh
```

`INTERVAL` 配置项控制更新频率（秒），脚本会自动转换为合适的 cron 表达式：

- `INTERVAL=3600` → 每小时
- `INTERVAL=21600` → 每 6 小时（默认）
- `INTERVAL=86400` → 每天

### 方式二：daemon 模式

适用于没有 cron 的环境（Docker 容器等）：

```bash
sudo update-clash-config --daemon
```

脚本会持续运行，按 `INTERVAL` 秒间隔循环拉取，日志输出到 `LOG_FILE`。

## 配置文件参考 (`clash-subscription.conf`)

```ini
# 订阅链接（必填）
SUBSCRIPTION_URL="https://example.com/sub"

# 输出目录
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

配置文件可复制改名用于多实例，通过 `-c` 指定即可。

## 多实例示例

```bash
# 实例 A — 机场 A
sudo update-clash-config -c /etc/clash-a.conf

# 实例 B — 机场 B
sudo update-clash-config -c /etc/clash-b.conf -d /etc/clash-b
```

## 日志

日志默认写入 `/var/log/clash-subscription.log`，格式：

```
[2025-01-15 10:30:00] [OK] Subscription saved to /etc/clash/config.yaml (size: 15234 bytes, HTTP 200)
[2025-01-15 10:30:00] [OK] Backed up existing config to /etc/clash/config.yaml.bak
[2025-01-15 12:00:00] [WARN] Attempt 1/3 — HTTP 503, retrying in ${RETRY_DELAY}s...
[2025-01-15 12:00:15] [FAIL] Failed to fetch subscription after 3 attempts (last HTTP 503)
```

## 卸载

```bash
# 完整卸载（交互式确认每一步）
sudo ./uninstall.sh

# 如果配置文件不在默认路径
sudo ./uninstall.sh -c /etc/my-clash.conf
```

卸载步骤：移除 cron 任务 → 删除 `/usr/local/bin/update-clash-config` → 删除配置文件 → 可选删除已下载的 config.yaml/日志文件。
