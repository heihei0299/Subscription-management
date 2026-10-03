# Clash Subscription Updater

拉取 Clash / Mihomo 订阅配置，可按计划更新并在成功后重启 `mihomo.service`。

## 安装与首次运行

~~~sh
sudo ./install.sh
sudo nano /etc/clash-subscription/clash-subscription.conf
sudo bash /etc/clash-subscription/update-clash-config
~~~

在配置文件中填写订阅链接。默认结果写入 `/etc/clash/config.yaml`，覆盖前会备份原文件。成功后会重启 Mihomo；没有 systemd 时跳过重启。

## 配置与参数

配置文件默认位于 `/etc/clash-subscription/clash-subscription.conf`。可用 `-c` 指定其他配置文件，用 `-u` 指定订阅链接、`-d` 指定输出目录。其他选项包括 `--user-agent`、`--interval`、`--log-file`、`--retry`、`--retry-delay`、`--timeout` 和 `--daemon`。

配置优先级：命令行参数 > 环境变量 > 配置文件 > 内置默认值。常用环境变量：`CLASH_URL`、`CLASH_OUTPUT_DIR`、`CLASH_UA`、`CLASH_INTERVAL`、`CLASH_LOG_FILE`、`CLASH_RETRY`、`CLASH_RETRY_DELAY`、`CLASH_TIMEOUT` 和 `CLASH_CONF`。

## 定时更新与卸载

推荐用 cron 注册定时任务：

~~~sh
sudo ./install-cron.sh
sudo crontab -l | grep clash
sudo ./uninstall-cron.sh
~~~

也可让脚本持续运行：

~~~sh
sudo bash /etc/clash-subscription/update-clash-config --daemon
~~~

卸载：

~~~sh
sudo ./uninstall.sh
~~~

卸载脚本会逐项确认；配置文件、生成的配置、备份和日志可选择保留或删除。